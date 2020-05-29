package org.ohdsi.bigKnn;

import java.util.ArrayList;
import java.util.List;

public class Test {

	public static void main(String[] args) {
		
		List<CovariateVector> covariateData = new ArrayList<CovariateVector>();
		covariateData.add(new CovariateVector(1.0, new double[]{10,11,12}, new double[]{1,1,1}));
		covariateData.add(new CovariateVector(2.0, new double[]{10,11}, new double[]{1,1}));
		covariateData.add(new CovariateVector(3.0, new double[]{12}, new double[]{1}));

		double[] nonZeroRowIds = new double[]{1};
		
		LuceneKnn luceneKnn = new LuceneKnn("c:/temp/Lucene");
//		luceneKnn.openForWriting(true);
//		luceneKnn.addNonZeroOutcomes(nonZeroRowIds);
//		for (CovariateVector covariateVector : covariateData) 
//			luceneKnn.addCovariates(covariateVector.rowId, covariateVector.covariateIds, covariateVector.covariateValues);
//		luceneKnn.finalizeWriting();
		
//		luceneKnn = new LuceneKnn("c:/temp/Lucene");
		luceneKnn.initPrediction(2);
		for (CovariateVector covariateVector : covariateData) 
			luceneKnn.predict(covariateVector.rowId, covariateVector.covariateIds, covariateVector.covariateValues);

		luceneKnn.setK(1);
		double[][] pred = luceneKnn.getPredictions();
		for (int i = 0; i < pred[0].length; i++)
			System.out.println("RowId: " + Math.round(pred[0][i]) + ", Prediction: " + pred[1][i]);
	}
	
	public static final class CovariateVector {
		public double[] covariateIds;
		public double[] covariateValues;
		public double rowId;
		
		public CovariateVector(double rowId, double[] covariateIds, double[] covariateValues) {
			this.covariateIds = covariateIds;
			this.covariateValues = covariateValues;
			this.rowId =  rowId;
		}
	}

}
