package org.ohdsi.bigKnn;

import java.io.File;
import java.io.IOException;
import java.io.StringReader;
import java.nio.file.FileSystems;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.ForkJoinPool;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.ReentrantLock;

import org.apache.lucene.analysis.core.WhitespaceAnalyzer;
import org.apache.lucene.document.Document;
import org.apache.lucene.document.Field;
import org.apache.lucene.document.FieldType;
import org.apache.lucene.document.StoredField;
import org.apache.lucene.document.StringField;
import org.apache.lucene.index.DirectoryReader;
import org.apache.lucene.index.IndexOptions;
import org.apache.lucene.index.IndexWriter;
import org.apache.lucene.index.IndexWriterConfig;
import org.apache.lucene.index.IndexWriterConfig.OpenMode;
import org.apache.lucene.queries.mlt.MoreLikeThis;
import org.apache.lucene.search.IndexSearcher;
import org.apache.lucene.search.Query;
import org.apache.lucene.search.ScoreDoc;
import org.apache.lucene.search.TopScoreDocCollector;
import org.apache.lucene.search.similarities.ClassicSimilarity;
import org.apache.lucene.search.similarities.Similarity;
import org.apache.lucene.store.FSDirectory;

public class LuceneKnn {

	private String indexFolder;
	private IndexSearcher searcher;
	private IndexWriter writer;
	private DirectoryReader reader;
	private WhitespaceAnalyzer analyzer = new WhitespaceAnalyzer();
	private Similarity similarity = new ClassicSimilarity();
	private Set<Long> nonZeroOutcomes;
	private int k = 100;
	private boolean weighted = true;
	private FieldType docAndFreqIndexed;
	private ExecutorService pool;
	private List<Prediction> predictions;
	private ReentrantLock lock = new ReentrantLock();

	public LuceneKnn(String indexFolder) {
		this.indexFolder = indexFolder;
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
			iwc.setSimilarity(similarity);
			iwc.setOpenMode(OpenMode.CREATE);
			iwc.setRAMBufferSizeMB(256.0);
			writer = new IndexWriter(dir, iwc);
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
		nonZeroOutcomes = new HashSet<Long>();

		docAndFreqIndexed = new FieldType();
		docAndFreqIndexed.setOmitNorms(false);
		docAndFreqIndexed.setIndexOptions(IndexOptions.DOCS_AND_FREQS);
		docAndFreqIndexed.setStored(false);
		docAndFreqIndexed.setTokenized(true);
		docAndFreqIndexed.freeze();
	}

	public void close() {
		try {
			if (writer != null)
				writer.close();
			if (reader != null)
				reader.close();
			System.gc();
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
	}

	public void addNonZeroOutcomes(double[] rowIds) {
		for (int i = 0; i < rowIds.length; i++)
			nonZeroOutcomes.add(Math.round(rowIds[i]));
	}

	public void addCovariates(double rowId, double[] covariateIds, double[] covariateValues) {
		try {
			long rowIdLong = Math.round(rowId);
			Document doc = new Document();
			doc.add(new StringField("rowId", Long.toString(rowIdLong), Field.Store.YES));
			StringBuilder string = new StringBuilder();
			for (int i = 0; i < covariateIds.length; i++) {
				for (int j = 0; j < Math.round(covariateValues[i]); j++) {
					string.append(Math.round(covariateIds[i]));
					string.append(' ');
				}
			}
			doc.add(new Field("covariates", string.toString(), docAndFreqIndexed));
			String classValue = (nonZeroOutcomes.contains(rowIdLong) ? "1" : "0");
			doc.add(new StoredField("class", classValue));
			writer.addDocument(doc);
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
	}

	public void finalizeWriting() {
		nonZeroOutcomes = null;
		try {
			writer.close();
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
		writer = null;
		System.gc();
	}

	public void initPrediction(int threads) {
		pool = new ForkJoinPool(threads);
		try {
			FSDirectory dir = FSDirectory.open(FileSystems.getDefault().getPath(indexFolder));
			reader = DirectoryReader.open(dir);
			searcher = new IndexSearcher(reader, pool);
			searcher.setSimilarity(similarity);
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
		predictions = new ArrayList<Prediction>();
	}

	public void predict(double rowId, double[] covariateIds, double[] covariateValues) {
		CovariateVector covariateVector = new CovariateVector();
		covariateVector.rowId = rowId;
		covariateVector.covariateIds = covariateIds;
		covariateVector.covariateValues = covariateValues;
		pool.execute(new PredictionTask(covariateVector));
	}

	public double[][] getPredictions() {
		try {
			pool.awaitTermination(10, TimeUnit.SECONDS);
		} catch (InterruptedException e1) {
			e1.printStackTrace();
		}
		try {
			reader.close();
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
		double[][] result = new double[][] { new double[predictions.size()], new double[predictions.size()] };
		for (int i = 0; i < predictions.size(); i++) {
			Prediction prediction = predictions.get(i);
			result[0][i] = prediction.rowId;
			result[1][i] = prediction.value;
		}
		System.gc();
		return result;
	}

	private double predictDoc(double[] covariateIds, double[] covariateValues) {
		try {
			TopScoreDocCollector collector = TopScoreDocCollector.create(getK(), getK());
			MoreLikeThis mlt = new MoreLikeThis(searcher.getIndexReader());
			mlt.setMinTermFreq(0);
			mlt.setFieldNames(new String[] { "covariates" });
			mlt.setMinWordLen(0);
			mlt.setMaxWordLen(9999);
			mlt.setAnalyzer(analyzer);
			mlt.setMinDocFreq(0);
			StringBuilder string = new StringBuilder();
			for (int i = 0; i < covariateIds.length; i++) {
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
			if (posScore + negScore == 0)
				return 0;
			else
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
		public double[] covariateIds;
		public double[] covariateValues;
		public double rowId;
	}

	private class Prediction {
		public double value;
		public double rowId;
	}
	
	private class PredictionTask implements Runnable {

		private CovariateVector covariateVector;

		public PredictionTask(CovariateVector covariateVector) {
			this.covariateVector = covariateVector;
		}

		@Override
		public void run() {
			double value = predictDoc(covariateVector.covariateIds, covariateVector.covariateValues);
			Prediction prediction = new Prediction();
			prediction.rowId = covariateVector.rowId;
			prediction.value = value;
			lock.lock();
			predictions.add(prediction);
			lock.unlock();
		}
	}
}
