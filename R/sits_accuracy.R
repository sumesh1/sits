#' @title Area-weighted classification accuracy assessment
#' @name sits_accuracy
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#' @author Alber Sanchez, \email{alber.ipia@@inpe.br}
#' @description To use this function the input table should be
#' a set of results containing
#' both the label assigned by the user and the classification result.
#' Accuracy assessment set us a confusion matrix to determine the accuracy
#' of your classified result.
#' This function uses an area-weighted technique proposed by Olofsson et al. to
#' produce more reliable accuracy estimates at 95% confidence level.
#'
#' This function performs an accuracy assessment of the classified, including
#' Overall Accuracy, User's Accuracy, Producer's Accuracy
#' and error matrix (confusion matrix) according to [1-2].
#'
#' @references
#' [1] Olofsson, P., Foody, G.M., Stehman, S.V., Woodcock, C.E. (2013).
#' Making better use of accuracy data in land change studies: Estimating
#' accuracy and area and quantifying uncertainty using stratified estimation.
#' Remote Sensing of Environment, 129, pp.122-131.
#'
#' @references
#' [2] Olofsson, P., Foody G.M., Herold M., Stehman, S.V.,
#' Woodcock, C.E., Wulder, M.A. (2014)
#' Good practices for estimating area and assessing accuracy of land change.
#' Remote Sensing of
#' Environment, 148, pp. 42-57.
#'
#' @param label_cube       A tibble with metadata about the classified maps.
#' @param validation_csv   A CSV file path with validation data
#'
#' @examples
#' \dontrun{
#' # get the samples for Mato Grosso for bands NDVI and EVI
#' samples_mt_ndvi <- sits_select(samples_mt_4bands, bands = c("NDVI"))
#' # filter the samples for three classes (to simplify the example)
#' samples_mt_ndvi <- dplyr::filter(samples_mt_ndvi, label %in%
#'                                    c("Forest", "Pasture", "Soy_Corn"))
#' # build an XGB model
#' xgb_model <- sits_train(samples_mt_ndvi,
#'                         sits_xgboost(nrounds = 10, verbose = FALSE))
#'
#' # files that make up the data cube
#' ndvi_file <- c(system.file("extdata/raster/mod13q1/sinop-ndvi-2014.tif",
#'                package = "sits"))
#' # create the data cube
#' sinop_2014 <- sits_cube(name = "sinop-2014",
#'                         timeline = timeline_2013_2014,
#'                         satellite = "TERRA",
#'                         sensor = "MODIS",
#'                         bands = c("NDVI"),
#'                         files = c(ndvi_file))
#'
#' # classify the data cube with xgb model
#' sinop_2014_probs <- sits_classify(sinop_2014,
#'                                   xgb_model,
#'                                   output_dir = tempdir(),
#'                                   memsize = 4,
#'                                   multicores = 1)
#' # label the classification
#' sinop_2014_label <- sits_label_classification(sinop_2014_probs,
#'                     output_dir = tempdir(),
#'                     smoothing = "bayesian")
#' # get ground truth points
#' ground_truth <- system.file("extdata/samples/samples_sinop_crop.csv",
#'                              package = "sits")
#' # calculate accuracy according to Olofsson's method
#' as <- suppressWarnings(sits_accuracy(sinop_2014_label, ground_truth))
#' }
#' @export
sits_accuracy <- function(label_cube, validation_csv) {

    assertthat::assert_that("classified_image" %in% class(label_cube),
                            msg = "sits_accuracy requires a labelled cube")

    assertthat::assert_that(file.exists(validation_csv),
                            msg = "sits_accuracy: validation file missing.")

    # read sample information from CSV file and put it in a tibble
    csv.tb <- tibble::as_tibble(utils::read.csv(validation_csv))

    # Precondition - check if CSV file is correct
    .sits_csv_check(csv.tb)

    # get xy in cube projection
    xy.tb <- .sits_latlong_to_proj(longitude = csv.tb$longitude,
                                   latitude = csv.tb$latitude,
                                   crs = label_cube$crs)

    # join lat-long with XY values in a single tibble
    points <- dplyr::bind_cols(csv.tb, xy.tb)

    # filter the points inside the data cube
    points_year <- dplyr::filter(points,
                                 X > label_cube$xmin & X < label_cube$xmax &
                                     Y > label_cube$ymin & Y < label_cube$ymax,
                                 start_date == label_cube$file_info[[1]]$date)

    # are there points to be retrieved from the cube?
    assertthat::assert_that(nrow(points_year) != 0,
        msg = "No validation point intersects the map's spatiotemporal extent.")

    # retain only xy inside the cube
    xy <- matrix(c(points_year$X, points_year$Y),
                 nrow = nrow(points_year), ncol = 2)
    colnames(xy) <- c("X", "Y")

    # open raster
    t_obj <- .sits_cube_terra_obj_band(cube = label_cube,
                                       band_cube = label_cube$bands)

    # extract classes
    predicted <- label_cube$labels[[1]][terra::extract(t_obj, xy)[,"lyr.1"]]

    # Get reference classes
    references <- points_year$label

    # Create error matrix
    error_matrix <- table(
        factor(predicted, levels = label_cube$labels[[1]],
               labels = label_cube$labels[[1]]),
        factor(references, levels = label_cube$labels[[1]],
               labels = label_cube$labels[[1]]))

    # Get area
    freq <- tibble::as_tibble(terra::freq(t_obj))
    area <- freq$count
    names(area) <- label_cube$labels[[1]][freq$value]
    area <- area[label_cube$labels[[1]]]
    names(area) <- label_cube$labels[[1]]
    area[is.na(area)] <- 0

    # Compute accuracy metrics
    assess <- .sits_assess_accuracy_area(error_matrix, area)

    # Print assessment values
    tb <- t(dplyr::bind_rows(assess$accuracy$user, assess$accuracy$producer))
    colnames(tb) <- c("User", "Producer")
    #
    print(knitr::kable(tb, digits = 2,
                       caption = "Users and Producers Accuracy per Class"))

    # print overall accuracy
    print(paste0("\nOverall accuracy is ", assess$accuracy$overall))

    return(assess)
}


#' @title Support for Area-weighted post-classification accuracy
#' @name .sits_assess_accuracy_area
#' @author Alber Sanchez, \email{alber.ipia@@inpe.br}
#'
#' @param error_matrix A matrix given in sample counts.
#'                     Columns represent the reference data and
#'                     rows the results of the classification
#' @param area         A named vector of the total area of each class on
#'                     the map
#'
#' @return
#' A list of lists: The error_matrix, the class_areas, the unbiased
#' estimated areas, the standard error areas, confidence interval 95% areas,
#' and the accuracy (user, producer, and overall).

.sits_assess_accuracy_area <- function(error_matrix, area){

    if (any(dim(error_matrix) == 0))
        stop("Invalid dimensions in error matrix.", call. = FALSE)
    if (length(unique(dim(error_matrix))) != 1)
        stop("The error matrix is not square.", call. = FALSE)
    if (!all(colnames(error_matrix) == rownames(error_matrix)))
        stop("Labels mismatch in error matrix.", call. = FALSE)
    if (unique(dim(error_matrix)) != length(area))
        stop("Mismatch between error matrix and area vector.",
             call. = FALSE)
    if (!all(names(area) %in% colnames(error_matrix)))
        stop("Label mismatch between error matrix and area vector.",
             call. = FALSE)

    # Re-order vector elements.
    area <- area[colnames(error_matrix)]

    W <- area / sum(area)
    n <- rowSums(error_matrix)

    p <- W * error_matrix / n
    p[is.na(p)] <- 0

    error_adjusted_area <- colSums(p) * sum(area)

    Sphat_1 <- sqrt(colSums((W * p - p ** 2) / (n - 1)))

    SAhat <- sum(area) * Sphat_1
    Ohat <- sum(diag(p))
    Uhat <- diag(p) / rowSums(p)
    Phat <- diag(p) / colSums(p)

    return(
        list(error_matrix = error_matrix,
             `area (pixels)` = area,
             `estimated area (pixels)` = error_adjusted_area,
             `area SE` = Sphat_1,
             `area SE (pixels)` = SAhat,
             `area CI 95% (pixels)` = 1.96 * SAhat,
             accuracy = list(user = Uhat, producer = Phat, overall = Ohat)))
}


