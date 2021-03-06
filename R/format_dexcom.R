#' Format DEXCOM data
#'
#' Format DEXCOM data into an analyzable dataframe.
#' @param input.path The name of the file which the data are to be read from.
#' @param rds.out The name of the output file
#' @param output.file logical. If TRUE, will output a list containing the formatted DEXCOM data and meta data.
#' @export
#'

format_dexcom <- function(input.path, rds.out=NULL, output.file=TRUE){
  if(grepl('xls', input.path)){
    dexcom <- xlsx::read.xlsx(input.path, sheetIndex=1, check.names=FALSE,
                              stringsAsFactors=FALSE,
                              colClasses=c('integer', rep('character', 6), rep('numeric', 2), 'POSIXct', rep('numeric', 2), 'character'))
    if(is.null(rds.out)){
      rds.out <- gsub('xls', 'RDS', input.path)
    }

    dexcom[, grep('Duration', names(dexcom), value=TRUE)] <- strftime(dexcom[, grep('Duration', names(dexcom), value=TRUE)],
                                                                      format='%H:%M:%S', tz='UTC')

  }else{
    dexcom <- utils::read.csv(input.path, header=TRUE, stringsAsFactors=FALSE,
                              check.names=FALSE, na.strings='')
    if(is.null(rds.out)){
      rds.out <- gsub('csv', 'RDS', input.path)
    }
  }

  names(dexcom) <- gsub(':|\\/| |-', '_', names(dexcom))
  names(dexcom) <- gsub('\\(|\\)', '', names(dexcom))
  #names(dexcom)[grepl('Index', names(dexcom))] <- 'Index'
  names(dexcom) <- iconv(names(dexcom), 'latin1', 'ASCII', sub='')

  meta.data <- dexcom[which(is.na(dexcom$Timestamp_YYYY_MM_DDThh_mm_ss)), ]
  names(meta.data) <- iconv(names(meta.data), 'latin1', 'ASCII', sub='')

  ## delete columns with only NAs
  remove.meta.cols <- sapply(meta.data, function(x) sum(is.na(x)))
  keep.meta.cols <- names(remove.meta.cols)[remove.meta.cols < nrow(meta.data)]
  meta.data <- meta.data[, keep.meta.cols]

  if('Patient_Info' %in% names(meta.data)){
    patient.meta.data <- meta.data[grep('FirstName|LastName|DateOfBirth', meta.data$Event_Type),
                                   c('Event_Type','Patient_Info')]
  }else{
    patient.meta.data <- NULL
  }

  meta.data <- meta.data[-grep('FirstName|LastName|DateOfBirth', meta.data$Event_Type), ]

  meta.data.list <- split(meta.data, f=meta.data$Source_Device_ID)
  meta.data.list <- lapply(meta.data.list, function(meta){
    meta$Device_Info[is.na(meta$Device_Info)] <- meta$Device_Info[!is.na(meta$Device_Info)];meta
    meta <- meta[!grepl('Device', meta$Event_Type), ]
  })

  #names(meta.data.list) <- paste0('Alert ', names(meta.data.list))

  #meta.data <- do.call(rbind, meta.data.list)

  if(!is.null(patient.meta.data)){
    meta.data.list <- c(list(patient.meta.data), meta.data.list)
    names(meta.data.list)[1] <- 'Patient Information'
  }

  ## informative meta data
  informative.meta.data <- lapply(meta.data.list, function(mdl){
    mdl <- mdl[, c('Event_Subtype', 'Glucose_Value_mg_dL')]
    mdl <- as.data.frame.matrix(t(mdl), stringsAsFactors=FALSE)
    names(mdl) <- mdl[1, ]
    mdl <- mdl[2, ]
    mdl <- mdl[, !is.na(mdl)]
    return(mdl)
  })

  ## dexcom cgm data
  cgm.data <- dexcom[-which(is.na(dexcom$Timestamp_YYYY_MM_DDThh_mm_ss)), ]

  ## delete columns with only NAs
  remove.cgm.cols <- sapply(cgm.data, function(x) sum(is.na(x)))
  keep.cgm.cols <- names(remove.cgm.cols)[remove.cgm.cols < nrow(cgm.data)]

  cgm.data <- cgm.data[, keep.cgm.cols[!grepl('Index', keep.cgm.cols)]]

  ## create date / time variable variable
  cgm.data$Timestamp_YYYY_MM_DD_hh_mm_ss <- gsub('T', ' ', cgm.data$Timestamp_YYYY_MM_DDThh_mm_ss)
  #cgm.data$Timestamp_YYYY_MM_DD_hh_mm_ss  <- gsub('\\..*', '', cgm.data$Timestamp_YYYY_MM_DD_hh_mm_ss )
  cgm.data$Timestamp_YYYY_MM_DD_hh_mm_ss <- base::as.POSIXct(lubridate::parse_date_time(cgm.data$Timestamp_YYYY_MM_DD_hh_mm_ss,
                                                                                        c("mdy HM", "mdy HMS", "mdY HM", "mdY HMS",
                                                                                          "dmy HM", "dmy HMS", "dmY HM", "dmY HMS", "Ymd HM", "Ymd HMS",
                                                                                          "ymd HM", "ymd HMS", "Ydm HM", "Ydm HMS", "ydm HM", "ydm HMS")),
                                                             tz='UTC')

  cgm.data$Timestamp_YYYY_MM_DDThh_mm_ss <- NULL

  cgm.data$Date <- as.Date(cgm.data$Timestamp_YYYY_MM_DD_hh_mm_ss)
  cgm.data$Year <- lubridate::year(cgm.data$Date)
  cgm.data$Month <- lubridate::month(cgm.data$Date)
  cgm.data$Day <- lubridate::day(cgm.data$Date)
  cgm.data$WeekDay <- factor(base::weekdays(cgm.data$Date, abbreviate=FALSE),
                             levels=weekdays(x=as.Date(0:6, origin='1950-01-01')))
  cgm.data$Time <- strftime(cgm.data$Timestamp_YYYY_MM_DD_hh_mm_ss, format='%H:%M:%S', tz='UTC')
  cgm.data$Hour <- lubridate::hour(strftime(cgm.data$Timestamp_YYYY_MM_DD_hh_mm_ss, fomrat='%H:%M:%S', tz='UTC'))
  cgm.data$Min <- lubridate::minute(strftime(cgm.data$Timestamp_YYYY_MM_DD_hh_mm_ss, fomrat='%H:%M:%S', tz='UTC'))
  cgm.data$Sec <- lubridate::second(strftime(cgm.data$Timestamp_YYYY_MM_DD_hh_mm_ss, fomrat='%H:%M:%S', tz='UTC'))

  cgm.data$Day_Time <- cgm.data$Day + ((cgm.data$Hour*60*60) + (cgm.data$Min*60) + (cgm.data$Sec))/86400

  cgm.data$TP <- month.name[cgm.data$Month]

  ## create a column to indicate levels of glucose warnings
  cgm.data$EGV_Warnings <- ifelse(cgm.data$Event_Type=='EGV' & grepl('^[A-Za-z]+$', cgm.data$Glucose_Value_mg_dL),
                                  cgm.data$Glucose_Value_mg_dL, NA)
  cgm.data$Glucose_Value_mg_dL <- as.numeric(cgm.data$Glucose_Value_mg_dL)

  cgm.data.list <- split(cgm.data, f=cgm.data$Source_Device_ID)

  ## determine if glucose variable is within, above, or below target
  cgm.data.list <- lapply(names(cgm.data.list), function(device){
    check <- meta.data.list[[device]]
    urgent.low <- as.numeric(check$Glucose_Value_mg_dL[which(check$Event_Subtype=='Urgent Low')])
    low <- as.numeric(check$Glucose_Value_mg_dL[which(check$Event_Subtype=='Low')])
    high <- as.numeric(check$Glucose_Value_mg_dL[which(check$Event_Subtype=='High')])
    temp <- cgm.data.list[[device]]
    temp$TARGET <- sapply(temp[,'Glucose_Value_mg_dL'], function(x){
      ifelse(is.na(x), NA,
             ifelse(x <= urgent.low, 'Urgent Low',
                    ifelse(x > urgent.low & x <= low, 'Low',
                           ifelse(x >= high, 'High', 'On Target'))))
    })
    return(temp)
  })

  cgm.data <- do.call(rbind, cgm.data.list)
  cgm.data <- cgm.data[order(cgm.data$Timestamp_YYYY_MM_DD_hh_mm_ss), ]

  if(any(!names(cgm.data) %in% 'Event_Subtype')){
    cgm.data[, 'Event_Subtype'] <- NA
  }

  ## create a copy without the high/low values in glucouse value mg dl column
  cgm.data.sub <- cgm.data
  cgm.data.sub <- cgm.data.sub[, !names(cgm.data.sub) %in% 'Event_Subtype']

  ## number of calibration(s) each day
  date.calibrations <- as.data.frame(table(cgm.data.sub$Event_Type, cgm.data.sub$Date), stringsAsFactors=FALSE)
  date.calibrations <- date.calibrations[which(date.calibrations$Var1=='Calibration'), ]

  ## determine what device were used
  ## if before Dexcom G6, remove those with less than 2 calibration
  if(any(sapply(meta.data.list,function(mdl) all(mdl$Device_Info!='Dexcom G6 Mobile App')))){
    before.g6 <- which(sapply(meta.data.list,function(mdl) all(mdl$Device_Info!='Dexcom G6 Mobile App')))
    names(before.g6) <- gsub('Alert ', '', names(before.g6))
    cgm.device <- split(cgm.data.sub, f=cgm.data.sub$Source_Device_ID)
    cgm.device <- lapply(names(cgm.device), function(x){
      if(x %in% names(before.g6)){
        temp <- cgm.device[[x]]
        ## dates with 2 or more calibrations
        date.calibrations <- date.calibrations[which(date.calibrations$Freq >= 2), ]
        date.calibrations$Var2 <- as.Date(date.calibrations$Var2)
        temp <- temp[temp$Date %in% date.calibrations$Var2, ]
        return(temp)
      }else{
        cgm.device[[x]]
      }
    })
    cgm.data.sub <- do.call(rbind, cgm.device)
  }

  if(dim(cgm.data.sub)[1] != 0){
    ## remove calibrations?
    cgm.data.sub <- cgm.data.sub[which(cgm.data.sub$Event_Type!='Calibration'), ]

    ## remove NAs (low/high)
    cgm.data.sub <- cgm.data.sub[!is.na(cgm.data.sub$Glucose_Value_mg_dL), ]

    ## number of calibration(s) each day
    date.calibrations <- data.frame(Dates=unique(cgm.data.sub$Date), stringsAsFactors=FALSE)

    ## check for consecutive dates
    dates <- sort(date.calibrations$Dates)
    dates.group <- split(dates, cumsum(c(TRUE, diff(dates)!=1)))

    ## split cgm data into groups based on dates
    cgm.data.sub.dates <- lapply(dates.group, function(dg){
      temp <- cgm.data.sub[cgm.data.sub$Date %in% dg, ]
      temp <- temp[order(temp$Timestamp_YYYY_MM_DD_hh_mm_ss), ]
      temp$Glucose_Value_mg_dL_v2 <- NA
      #temp$Time_diff <- c(TRUE, diff(temp$Timestamp_YYYY_MM_DD_hh_mm_ss) > 270 & diff(temp$Timestamp_YYYY_MM_DD_hh_mm_ss) < 630)
      for(i in 3:(nrow(temp)-2)){
        check.value <- temp[i, 'Glucose_Value_mg_dL']
        intermediate.sv <- temp[((i-2):(i+2))[!((i-2):(i+2)) %in% i], ]
        i.sv.mean <- mean(intermediate.sv$Glucose_Value_mg_dL, na.rm=TRUE)
        i.sv.sd <- sd(intermediate.sv$Glucose_Value_mg_dL, na.rm=TRUE)

        upp.b <- i.sv.mean + i.sv.sd
        low.b <- i.sv.mean - i.sv.sd

        if(!(check.value >= low.b & check.value <= upp.b)){
          temp[i, 'Glucose_Value_mg_dL_v2'] <- i.sv.mean
        }
        temp$Glucose_Value_mg_dL_v2[is.na(temp$Glucose_Value_mg_dL_v2)] <- temp$Glucose_Value_mg_dL[is.na(temp$Glucose_Value_mg_dL_v2)]

      }

      return(temp)
    })

    cgm.data.sub <- do.call(rbind, cgm.data.sub.dates)
  }

  cgm.data$Timestamp_YYYY_MM_DD_hh_mm_ss <- cgm.data$Transmitter_Time_Long_Integer <- NULL

  cgm.data.sub <- cgm.data.sub[order(cgm.data.sub$Timestamp_YYYY_MM_DD_hh_mm_ss), ]
  cgm.data.sub$Timestamp_YYYY_MM_DD_hh_mm_ss <- cgm.data.sub$Transmitter_Time_Long_Integer <- NA

  meta.data.list <- lapply(meta.data.list, function(mdl){
    mdl$TP <- unique(cgm.data$TP);mdl
  })

  informative.meta.data <- lapply(informative.meta.data, function(mdl){
    mdl$TP <- unique(cgm.data$TP); mdl
  })

  saveRDS(list(full.cgm.data=cgm.data,
               cleaned.cgm.data=cgm.data.sub,
               meta.data=meta.data.list,
               informative.meta.data=informative.meta.data),
          file=rds.out)

  if(output.file==TRUE){
  return(list(full.cgm.data=cgm.data,
              informative.meta.data=informative.meta.data))
  }

}

utils::globalVariables(names=c('sd'))
