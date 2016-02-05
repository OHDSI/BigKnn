package org.ohdsi.bigKnn;

import java.io.File;
import java.io.IOException;
import java.io.StringReader;
import java.nio.file.FileSystems;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.apache.lucene.analysis.core.WhitespaceAnalyzer;
import org.apache.lucene.document.Document;
import org.apache.lucene.document.Field.Store;
import org.apache.lucene.document.LongField;
import org.apache.lucene.document.StoredField;
import org.apache.lucene.document.TextField;
import org.apache.lucene.index.DirectoryReader;
import org.apache.lucene.index.IndexWriter;
import org.apache.lucene.index.IndexWriterConfig;
import org.apache.lucene.index.IndexWriterConfig.OpenMode;
import org.apache.lucene.queries.mlt.MoreLikeThis;
import org.apache.lucene.search.IndexSearcher;
import org.apache.lucene.search.Query;
import org.apache.lucene.search.ScoreDoc;
import org.apache.lucene.search.TopScoreDocCollector;
import org.apache.lucene.store.FSDirectory;

public class LuceneKnn {

	private String				indexFolder;
	private IndexSearcher		searcher;
	private IndexWriter			writer;
	private DirectoryReader		reader;
	private WhitespaceAnalyzer	analyzer	= new WhitespaceAnalyzer();
	private CovariateVector		cache;
	private Set<Long>			nonZeroOutcomes;
	private int					k			= 100;
	private boolean				weighted	= true;

	public LuceneKnn(String indexFolder) {
		this.indexFolder = indexFolder;
	}

	public void openForReading() {
		try {
			FSDirectory dir = FSDirectory.open(FileSystems.getDefault().getPath(indexFolder));
			reader = DirectoryReader.open(dir);
			searcher = new IndexSearcher(reader);
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
	}

	public void openForWriting(boolean overwrite) {
		try {
			if (new File(indexFolder).exists()) {
				File folder = new File(indexFolder);
				File[] files = folder.listFiles();
				for (File f : files)
					f.delete();
				folder.delete();
			}
			FSDirectory dir = FSDirectory.open(FileSystems.getDefault().getPath(indexFolder));
			IndexWriterConfig iwc = new IndexWriterConfig(analyzer);
			iwc.setOpenMode(OpenMode.CREATE);
			iwc.setRAMBufferSizeMB(256.0);
			writer = new IndexWriter(dir, iwc);
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
		nonZeroOutcomes = new HashSet<Long>();
	}

	public void close() {
		try {
			if (writer != null)
				writer.close();
			if (reader != null)
				reader.close();
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
	}

	public void addNonZeroOutcomes(double[] rowIds) {
		for (int i = 0; i < rowIds.length; i++)
			nonZeroOutcomes.add(Math.round(rowIds[i]));
	}

	public void addCovariates(double[] rowIds, double[] covariateIds, double[] covariateValues) {
		if (rowIds.length == 0)
			return;
		if (nonZeroOutcomes.size() == 0)
			throw new RuntimeException("No outcomes found. Please load the outcomes before loading the covariates.");

		int cursor = 0;
		int start = 0;

		// Check to see if anythings left in the cache from the previous round:
		if (cache != null) {
			while (rowIds[cursor] == cache.rowId)
				cursor++;
			double[] tempCovariateIds = new double[cache.covariateIds.length + cursor];
			double[] tempCovariateValues = new double[cache.covariateValues.length + cursor];
			System.arraycopy(cache.covariateIds, 0, tempCovariateIds, 0, cache.covariateIds.length);
			System.arraycopy(cache.covariateValues, 0, tempCovariateValues, 0, cache.covariateValues.length);
			if (cursor > 0) {
				System.arraycopy(covariateIds, 0, tempCovariateIds, 0, cursor);
				System.arraycopy(covariateValues, 0, tempCovariateValues, 0, cursor);
			}
			addDoc(cache.rowId, tempCovariateIds, tempCovariateValues, 0, tempCovariateIds.length);
			cache = null;
			start = cursor;
		}
		double rowId = rowIds[cursor];
		while (cursor < covariateIds.length) {
			if (rowIds[cursor] != rowId) {
				addDoc(rowId, covariateIds, covariateValues, start, cursor);
				start = cursor;
				rowId = rowIds[cursor];
			}
			cursor++;
		}
		cache = new CovariateVector();
		cache.rowId = rowId;
		cache.covariateIds = new double[cursor - start];
		cache.covariateValues = new double[cursor - start];
		System.arraycopy(covariateIds, start, cache.covariateIds, 0, cursor - start);
		System.arraycopy(covariateValues, start, cache.covariateValues, 0, cursor - start);
	}

	public void finalizeWriting() {
		addDoc(cache.rowId, cache.covariateIds, cache.covariateValues, 0, cache.covariateIds.length);
		nonZeroOutcomes = null;
		try {
			writer.close();
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
		writer = null;
		System.gc();
	}

	private void addDoc(double rowId, double[] covariateIds, double[] covariateValues, int start, int end) {
		try {
			long rowIdLong = Math.round(rowId);
			Document doc = new Document();
			doc.add(new LongField("rowId", rowIdLong, Store.YES));
			StringBuilder string = new StringBuilder();
			for (int i = start; i < end; i++) {
				for (int j = 0; j < Math.round(covariateValues[i]); j++) {
					string.append(Math.round(covariateIds[i]));
					string.append(' ');
				}
			}
			doc.add(new TextField("covariates", string.toString(), Store.NO));
			String classValue = (nonZeroOutcomes.contains(rowIdLong) ? "1" : "0");
			doc.add(new StoredField("class", classValue));
			writer.addDocument(doc);
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
	}

	public double[][] predict(double[] rowIds, double[] covariateIds, double[] covariateValues) {
		if (rowIds.length == 0)
			return new double[][] { new double[0], new double[0] };

		List<Double> outRowIds = new ArrayList<Double>();
		List<Double> outPredictions = new ArrayList<Double>();

		int cursor = 0;
		int start = 0;

		// Check to see if anythings left in the cache from the previous round:
		if (cache != null) {
			while (rowIds[cursor] == cache.rowId)
				cursor++;
			double[] tempCovariateIds = new double[cache.covariateIds.length + cursor];
			double[] tempCovariateValues = new double[cache.covariateValues.length + cursor];
			System.arraycopy(cache.covariateIds, 0, tempCovariateIds, 0, cache.covariateIds.length);
			System.arraycopy(cache.covariateValues, 0, tempCovariateValues, 0, cache.covariateValues.length);
			if (cursor > 0) {
				System.arraycopy(covariateIds, 0, tempCovariateIds, 0, cursor);
				System.arraycopy(covariateValues, 0, tempCovariateValues, 0, cursor);
			}
			outRowIds.add(cache.rowId);
			double prediction = predictDoc(tempCovariateIds, tempCovariateValues, 0, tempCovariateIds.length);
			outPredictions.add(prediction);
			cache = null;
			start = cursor;
		}
		double rowId = rowIds[cursor];
		while (cursor < covariateIds.length) {
			if (rowIds[cursor] != rowId) {
				outRowIds.add(rowId);
				double prediction = predictDoc(covariateIds, covariateValues, start, cursor);
				outPredictions.add(prediction);
				start = cursor;
				rowId = rowIds[cursor];
			}
			cursor++;
		}
		cache = new CovariateVector();
		cache.rowId = rowId;
		cache.covariateIds = new double[cursor - start];
		cache.covariateValues = new double[cursor - start];
		System.arraycopy(covariateIds, start, cache.covariateIds, 0, cursor - start);
		System.arraycopy(covariateValues, start, cache.covariateValues, 0, cursor - start);
		double[][] result = new double[][] { new double[outRowIds.size()], new double[outPredictions.size()] };
		for (int i = 0; i < outRowIds.size(); i++) {
			result[0][i] = outRowIds.get(i);
			result[1][i] = outPredictions.get(i);
		}
		return result;
	}

	public double[][] finalizePredict() {
		double prediction = predictDoc(cache.covariateIds, cache.covariateValues, 0, cache.covariateIds.length);
		double rowId = cache.rowId;
		cache = null;
		try {
			reader.close();
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
		System.gc();
		return new double[][] { new double[] { rowId }, new double[] { prediction } };
	}

	private double predictDoc(double[] covariateIds, double[] covariateValues, int start, int end) {
		try {
			TopScoreDocCollector collector = TopScoreDocCollector.create(getK());
			MoreLikeThis mlt = new MoreLikeThis(searcher.getIndexReader());
			mlt.setMinTermFreq(0);
			mlt.setFieldNames(new String[] { "covariates" });
			mlt.setMinWordLen(0);
			mlt.setMaxWordLen(9999);
			mlt.setAnalyzer(analyzer);
			mlt.setMinDocFreq(0);
			StringBuilder string = new StringBuilder();
			for (int i = start; i < end; i++) {
				for (int j = 0; j < Math.round(covariateValues[i]); j++) {
					string.append(Math.round(covariateIds[i]));
					string.append(' ');
				}
			}
			Query query = mlt.like("covariates", new StringReader(string.toString()));
			searcher.search(query, collector);
			double posScore = 0;
			double negScore = 0;
			for (ScoreDoc scoreDoc : collector.topDocs().scoreDocs) {
				if (weighted) {
					if (reader.document(scoreDoc.doc).get("class").equals("1"))
						posScore += scoreDoc.score;
					else
						negScore += scoreDoc.score;
				} else {
					if (reader.document(scoreDoc.doc).get("class").equals("1"))
						posScore++;
					else
						negScore++;
				}
			}
			return posScore / (posScore + negScore);
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
	}

	public String getIndexFolder() {
		return indexFolder;
	}

	public void setIndexFolder(String indexFolder) {
		this.indexFolder = indexFolder;
	}

	public int getK() {
		return k;
	}

	public void setK(int k) {
		this.k = k;
	}

	public boolean isWeighted() {
		return weighted;
	}

	public void setWeighted(boolean weighted) {
		this.weighted = weighted;
	}

	private class CovariateVector {
		public double[]	covariateIds;
		public double[]	covariateValues;
		public double	rowId;
	}
}
