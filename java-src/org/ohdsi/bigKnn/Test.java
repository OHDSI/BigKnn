package org.ohdsi.bigKnn;

public class Test {

	public static void main(String[] args) {
		double[] covRowIds = new double[]{1,1,1,2,2,3};
		double[] covCovariateIds = new double[]{10,11,12,10,11,12};
		double[] covCovariateValues = new double[]{1,1,1,1,1,1};
		
		double[] nonZeroRowIds = new double[]{1};
		
		LuceneKnn luceneKnn = new LuceneKnn("s:/temp/Lucene2");
		luceneKnn.openForWriting(true);
		luceneKnn.addNonZeroOutcomes(nonZeroRowIds);
		luceneKnn.addCovariates(covRowIds, covCovariateIds, covCovariateValues);
		luceneKnn.finalizeWriting();
		
		luceneKnn = new LuceneKnn("s:/temp/Lucene");
		luceneKnn.openForReading();
		double[][] pred = luceneKnn.predict(covRowIds, covCovariateIds, covCovariateValues);
		double[][] predLast = luceneKnn.finalizePredict();
		for (int i = 0; i < pred[0].length; i++)
			System.out.println("RowId: " + Math.round(pred[0][i]) + ", Prediction: " + pred[1][i]);
		System.out.println("RowId: " + Math.round(predLast[0][0]) + ", Prediction: " + predLast[1][0]);
	}

}
