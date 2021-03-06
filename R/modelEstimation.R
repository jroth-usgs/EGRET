#' Estimation process for the WRTDS (Weighted Regressions on Time, Discharge, and Season)
#'
#' This one function does a jack-knife cross-validation of a WRTDS model, fits the surface
#' (concentration as a function of discharge and time), 
#' estimates daily values of concentration and flux, and flow normalized values. 
#' It returns a named list with the following dataframes: Daily, INFO, Sample, and the matrix: surfaces.
#'
#' @param eList named list with at least the Daily, Sample, and INFO dataframes
#' @param windowY numeric specifying the half-window width in the time dimension, in units of years, default is 7
#' @param windowQ numeric specifying the half-window width in the discharge dimension, units are natural log units, default is 2
#' @param windowS numeric specifying the half-window with in the seasonal dimension, in units of years, default is 0.5
#' @param minNumObs numeric specifying the miniumum number of observations required to run the weighted regression, default is 100
#' @param minNumUncen numeric specifying the minimum number of uncensored observations to run the weighted regression, default is 50
#' @param edgeAdjust logical specifying whether to use the modified method for calculating the windows at the edge of the record.  
#' The modified method tends to reduce curvature near the start and end of record.  Default is TRUE.
#' @keywords water-quality statistics
#' @export
#' @return eList named list with Daily, Sample, and INFO dataframes, along with the surfaces matrix.
#' Any of these values can be NA, not all EGRET functions will work with missing parts of the named list eList.
#' @examples
#' eList <- Choptank_eList
#' \dontrun{
#'  
#' #Run an estimation adjusting windowQ from default:
#' eList <- modelEstimation(eList, windowQ=5)
#' }
modelEstimation<-function(eList, 
                          windowY=7, windowQ=2, windowS=0.5,
                          minNumObs=100,minNumUncen=50, 
                          edgeAdjust=TRUE){

  eList <- setUpEstimation(eList=eList, windowY=windowY, windowQ=windowQ, windowS=windowS,
                  minNumObs=minNumObs, minNumUncen=minNumUncen,edgeAdjust=edgeAdjust)

  cat("\n first step running estCrossVal may take about 1 minute")
  Sample1<-estCrossVal(length(eList$Daily$DecYear),eList$Daily$DecYear[1],
                       eList$Daily$DecYear[length(eList$Daily$DecYear)], 
                       eList$Sample, 
                       windowY=windowY, windowQ=windowQ, windowS=windowS,
                       minNumObs=minNumObs, minNumUncen=minNumUncen,edgeAdjust=edgeAdjust)
  
  eList$Sample <- Sample1
  
  cat("\nNext step running  estSurfaces with survival regression:\n")
  surfaces1 <- estSurfaces(eList, 
                         windowY=windowY, windowQ=windowQ, windowS=windowS,
                         minNumObs=minNumObs, minNumUncen=minNumUncen,edgeAdjust=edgeAdjust)

  eList$surfaces <- surfaces1
  
  Daily1<-estDailyFromSurfaces(eList)
  
  eList$Daily <- Daily1
  
  return(eList)
  
}



#' setUpEstimation
#' 
#' Set up the INFO data frame for a modelEstimation
#' 
#' @param eList named list with at least the Daily, Sample, and INFO dataframes
#' @param windowY numeric specifying the half-window width in the time dimension, in units of years, default is 7
#' @param windowQ numeric specifying the half-window width in the discharge dimension, units are natural log units, default is 2
#' @param windowS numeric specifying the half-window with in the seasonal dimension, in units of years, default is 0.5
#' @param minNumObs numeric specifying the miniumum number of observations required to run the weighted regression, default is 100
#' @param minNumUncen numeric specifying the minimum number of uncensored observations to run the weighted regression, default is 50
#' @param edgeAdjust logical specifying whether to use the modified method for calculating the windows at the edge of the record.  
#' The modified method tends to reduce curvature near the start and end of record.  Default is TRUE.
#' @param interactive logical Option for interactive mode.  If true, there is user interaction for error handling and data checks.
#' @keywords water-quality statistics
#' @export
#' @return eList named list with Daily, Sample, and INFO dataframes.
#' @examples
#' eList <- Choptank_eList
#' eList <- setUpEstimation(eList)
#' 
setUpEstimation<-function(eList, 
                          windowY=7, windowQ=2, windowS=0.5,
                          minNumObs=100,minNumUncen=50, 
                          edgeAdjust=TRUE, interactive=TRUE){

  localINFO <- getInfo(eList)
  localSample <- getSample(eList)
  localDaily <- getDaily(eList)
  
  if(!all(c("Q","LogQ") %in% names(localSample))){
    eList <- mergeReport(INFO=localINFO, Daily = localDaily, Sample = localSample, interactive=interactive)
  }
  
  if(any(localSample$ConcLow[!is.na(localSample$ConcLow)] == 0)){
    stop("modelEstimation cannot be run with 0 values in ConcLow. An estimate of the reporting limit needs to be included. See fixSampleFrame to adjust the Sample data frame")
  }
  
  numDays <- length(localDaily$DecYear)
  DecLow <- localDaily$DecYear[1]
  DecHigh <- localDaily$DecYear[numDays]
    
  surfaceIndexParameters<-surfaceIndex(localDaily)
  localINFO$bottomLogQ<-surfaceIndexParameters[1]
  localINFO$stepLogQ<-surfaceIndexParameters[2]
  localINFO$nVectorLogQ<-surfaceIndexParameters[3]
  localINFO$bottomYear<-surfaceIndexParameters[4]
  localINFO$stepYear<-surfaceIndexParameters[5]
  localINFO$nVectorYear<-surfaceIndexParameters[6]
  localINFO$windowY<-windowY
  localINFO$windowQ<-windowQ
  localINFO$windowS<-windowS
  localINFO$minNumObs<-minNumObs
  localINFO$minNumUncen<-minNumUncen
  localINFO$numDays <- numDays
  localINFO$DecLow <- DecLow
  localINFO$DecHigh <- DecHigh
  localINFO$edgeAdjust <- edgeAdjust
  
  eList$INFO <- localINFO
  
  return(eList)
  
}
