#' Constructor function for S3 class representing an NGS Data object.
#'
#' \code{Data} returns constructed Data object.
#'
#' @param path A character string representing the absolute path to sequence file.
#' @param datatype A character string representing the file type. Default value is file extension (last of all period (".") separated extensions).
#' @param seqtype A character string representing the sequence type. Options: "nucleotide" (default) or "amino acid".
#'
#' @return Returns a constructed S3 object which is a child object of a parent session object, inherits from the following classes:
#' \itemize{
#' \item \code{datatype}: The file type of NGS file represeted by the object.
#' \item \code{seqtype}: The sequence type of the sequences in the NGS file represeted by the object.
#' \item \code{Data}.
#' \item \code{environment}.
#' }
#' and contains the following elements:
#' \itemize{
#' \item \code{path}: The absolute path to the NGS file represented by the object.
#' \item \code{raw_seq}: A list that will contain the parsed sequences of the NGS file.
#' \item \code{compressed}: An S3 object that inherits from the base \code{environment} class and will contain the compressed sequences of the NGS file.
#' \item \code{sample}: An S3 object that inherits from the base \code{environment} class and will contain randomly sampled sequences from the the compressed structure.
#' \item \code{master}: A character string representing the master sequence to use for plotting.
#' \item \code{seq_diff}: A character matrix of sequence differences in variant sequences compared to the master sequence.
#' }
Data <-  function(path, datatype = tail(strsplit(path, "\\.")[[1]], n = 1), seqtype = "nucleotide") {
  # validate file exists
  if (!file.exists(path)) {
    stop(paste0("ERROR: file '", path, "' not found")
    )
  }

  # validate file type
  if (tolower(datatype) %in% c("fasta", "fa", "fas")) {
    datatype <- "fasta"
  }
  else if (tolower(datatype) %in% c("fastq", "fq")) {
    datatype <- "fastq"
  }
  else if (tolower(datatype) == "csv") {
    datatype <- "csv"
  }
  else {
    stop(paste0("ERROR: file '", path, "' not imported. highlineR does not know how to handle files of type ",
                datatype,
                " and can only be used on fasta and fastq files")
    )
  }

  # validate sequence type
  seqtype <- match.arg(tolower(seqtype), c("nucleotide", "amino acid"))

  # create s3 Data structure
  data <- structure(
    as.environment(
      list(
        path = path,
        raw_seq = list(),
        compressed =
          structure(
            new.env(),
            class = c("compressed", "environment")
          ),
        sample =
          structure(
            new.env(),
            class = c("compressed", "environment")
          ),
        master = character(),
        seq_diff = matrix()
      )
    ),
    class = c(datatype, seqtype, "Data", "environment")
  )

  parent.env(data$compressed) <- data
  parent.env(data$sample) <- data

  data
}

#' Remove Data object from highlineR session environment.
#'
#' \code{remove_Data} removes a Data object from a highlineR session environment.
#'
#' @param data \code{Data} object or character string of absolute path of existing Data object.
#' @param session \code{session} object or character string name of \code{session} object containing Data object to be removed. Default is "highlineR.session".
#'
#' @return Removes specified \code{Data} object from specified \code{session}.
remove_Data <- function(data, session = "highlineR.session") {
  if (is.character(session)){
    session <- get(session)
  }

  if (is.character(data)) {
    # check if specified Data objec exists in specified session
    stopifnot(exists(data, envir = session))
    # remove
    rm(list=data, envir = session)
  }
  else {
    # if Data object provided
    stopifnot(inherits(data, "Data"))
    rm(list=data$path, envir = parent.env(data))
  }
}

#' Constructor function for S3 class representing container for Data objects.
#'
#' \code{init_session} returns constructed session object.
#'
#' @param session character string represting name of session to be created.
#'
#' @return Returns a constructed S3 object which inherits from the following classes:
#' \itemize{
#' \item \code{session}.
#' \item \code{environment}.
#' }
#' and contains an environement that will hold Data objects.
init_session <- function(session = "highlineR.session") {
  assign(session,
         structure(new.env(), class = c("session", "environment")),
         envir = .GlobalEnv
  )
  get(session)
}

#' Remove session object from global environment.
#'
#' \code{close_session} removes a session object from the global R environment.
#'
#' @param session \code{session} object or character string name of \code{session} object to be removed. Default is "highlineR.session".
#'
#' @return Removes specified \code{session} object from global R environment.
close_session <- function(session = "highlineR.session") {
  if (! is.character(session)) {
    session <- deparse(substitute(session))
  }
  stopifnot(exists(session))

  # check session argument is of session class
  stopifnot(inherits(get(session, envir = .GlobalEnv), "session"))

  rm(list=paste(session), envir = .GlobalEnv)
}

#' Import NGS file.
#'
#' \code{import_file} creates a Data object for an NGS file.
#'
#' @param path A character string representing the absolute path to sequence file.
#' @param datatype A character string representing the file type. Default value is file extension (last of all period (".") separated extensions).
#' @param seqtype A character string representing the sequence type. Options: "nucleotide" (default) or "amino acid".
#' @param session \code{session} object or character string name of \code{session} object into which NGS data should be imported. Default is "highlineR.session".
#' @param force A logical value specifying if previously imported file should be overwritten and re-imported.
#'
#' @return Imports specified NGS file into specified highlineR session.
#'
#' @keywords internal
import_file <- function(path, datatype, seqtype, session, force = FALSE) {
  if (missing(session)) {
    stop("highlineR session not specified.")
  }
  stopifnot(is.character(session))

  stopifnot(is.character(path))
  stopifnot(file.exists(path))
  stopifnot(is.logical(force))

  if (! missing(datatype)) {
    stopifnot(is.character(datatype))
  }

  if (! missing(seqtype)) {
    stopifnot(is.character(seqtype))
  }

  # create environment if it doesn't exist
  if (! exists(session)) {
    init_session(session)
  }

  # ignore files already imported unless forced
  if (force == FALSE && exists(path, envir = get(session), inherits = FALSE)) {
    warning(paste("File", path, "ignored. Already imported in", session, "session."))
  }
  # otherwise create Data object within specified session
  else {
    if (missing(datatype) && missing(seqtype)) {
      data <- Data(path)
    }
    else if (missing(datatype)) {
      data <- Data(path, seqtype = seqtype)
    }
    else if (missing(seqtype)) {
      data <- Data(path, datatype = datatype)
    }
    else {
      data <- Data(path, datatype = datatype, seqtype = seqtype)
    }
    parent.env(data) <- get(session)
    assign(path, data, envir = get(session))
  }
}

#' Import NGS file(s).
#'
#' \code{import_raw_seq} creates Data object(s) for NGS file(s).
#'
#' @param path A character string representing an absolute path to an NGS file, an absolute path to a directory of NGS files or a character vector of absolute paths to NGS files.
#' @param datatype A character string representing the file type. Value is inferred from file extension or specified by user as "fasta" or "fastq.
#' @param seqtype A character string representing the sequence type. Options: "nucleotide" (default) or "amino acid".
#' @param session \code{session} object or character string name of \code{session} object into which NGS data should be imported. Default is "highlineR.session".
#' @param force A logical value specifying if previously imported file should be overwritten and re-imported.
#'
#' @return Returns \code{session} object into which NGS data file(s) were imported.
import_raw_seq <- function(path, datatype, seqtype, session = "highlineR.session", force = FALSE) {
  # validate path
  if (length(path) == 1) {
    if(!file.exists(path)) {
      stop(paste0("ERROR: path '", path, "' not valid"))
    }
  }

  # if path is directory or list of files, import each file
  if (length(path) >1 || dir.exists(path)) {
    tmp.list.1 <- ""
    if (length(path) == 1) {
      # remove trailing backslash
      path <- sub("\\/$", "", path)
      tmp.list.1 <- list.files(path, full.names = TRUE)
    }
    else{
      tmp.list.1 <- path
    }


    for (i in 1:length(tmp.list.1)) {
      result <- tryCatch(
        if (missing(datatype) && missing(seqtype)) {
          import_file(tmp.list.1[i], session = session, force = force)
        }
        else if (missing(seqtype)) {
          import_file(tmp.list.1[i], datatype = datatype, session = session, force = force)
        }
        else if (missing(datatype)) {
          import_file(tmp.list.1[i], seqtype = seqtype, session = session, force = force)
        }
        else {
          import_file(tmp.list.1[i], datatype = datatype, seqtype = seqtype, session = session, force = force)
        }
        , error = function(e) {
          warning(e)
          e
        }
        , warning = function(w) {
          warning(w)
        }
      )
      if (inherits(result, "error"))
        next
    }
  }
  # if path is file, import file
  else {
    if (missing(datatype) && missing(seqtype)) {
      import_file(path, session = session, force = force)
    }
    else if (missing(seqtype)) {
      import_file(path, datatype = datatype, session = session, force = force)
    }
    else if (missing(datatype)) {
      import_file(path, seqtype = seqtype, session = session, force = force)
    }
    else {
      import_file(path, datatype = datatype, seqtype = seqtype, session = session, force = force)
    }

  }

  get(session)
}