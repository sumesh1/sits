#' @title Get information from collection
#' @name .sits_stac_collection
#' @keywords internal
#'
#' @param url         a \code{character} representing a URL for the BDC catalog.
#' @param collection  a \code{character} with the collection to be searched.
#' @param bands       a \code{character} with the bands names to be filtered.
#' @param ...        other parameters to be passed for specific types.

#'
#' @return            a \code{STACCollection} object returned by rstac.
.sits_stac_collection <- function(url         = NULL,
                                  collection  = NULL,
                                  bands       = NULL, ...) {

    assertthat::assert_that(!purrr::is_null(url),
                            msg = paste("sits_cube: for STAC_CUBE url must be",
                                        "provided"))

    assertthat::assert_that(!purrr::is_null(collection),
                msg = paste("sits_cube: for STAC_CUBE collections",
                            "must be provided"))

    assertthat::assert_that(!(length(collection) > 1),
                msg = paste("sits_cube: STAC_CUBE ",
                            "only one collection should be specified"))

    # creating a rstac object and making the requisition
    collection_info <- rstac::stac(url) %>%
        rstac::collections(collection_id = collection) %>%
        rstac::get_request(...)

    # get the name of the bands
    collection_bands <- sapply(collection_info$properties[["eo:bands"]],
                               `[[`, c("name"))

    # checks if the supplied bands match the product bands
    if (!is.null(bands)) {
        assertthat::assert_that(all(bands %in% collection_bands),
                                msg = paste("The supplied bands do not match",
                                            "the data cube bands."))

        collection_bands <- collection_bands[collection_bands %in% bands]
    }

    # Add bands information as an attribute
    collection_info$bands <- collection_bands

    return(collection_info)
}
#' @title Get information from items
#' @name .sits_stac_items
#' @keywords internal
#'
#' @param url        a \code{character} representing a URL for the BDC catalog.
#' @param collection a \code{character} with the collection to be searched.
#' @param tiles      a \code{character} with the names of the tiles.
#' @param roi        defines a region of interest. It can be
#'                   an \code{sfc} or \code{sf} object from sf package,
#'                   a \code{character} with a GeoJSON using RFC 7946,
#'                   or a \code{vector} bounding box \code{vector}
#'                   with named XY values ("xmin", "xmax", "ymin", "ymax").
#' @param start_date a \code{character} corresponds to the initial date
#'                   when the cube will be created.
#' @param end_date   a \code{character} corresponds to the final date when the
#'                   cube will be created.
#' @param ...        other parameters to be passed for specific types.
#'
#' @return           a \code{STACItemCollection} object
#'                   representing the search by rstac.
.sits_stac_items <- function(url        = NULL,
                             collection = NULL,
                             tiles      = NULL,
                             roi        = NULL,
                             start_date = NULL,
                             end_date   = NULL, ...) {

    # obtain the datetime parameter for STAC like parameter
    datetime <- .sits_stac_datetime(start_date, end_date)

    # obtain the bbox and intersects parameters
    if (!is.null(roi)) {
        roi <- .sits_stac_roi(roi)
    } else {
        roi[c("bbox", "intersects")] <- list(NULL, NULL)
    }

    # creating a rstac object
    rstac_query <- rstac::stac(url) %>%
        rstac::stac_search(collection = collection,
                           bbox       = roi$bbox,
                           intersects = roi$intersects,
                           datetime   = datetime)

    # if specified, a filter per tile is added to the query
    if (!is.null(tiles))
        rstac_query <- rstac_query %>%
            rstac::ext_query(keys = "bdc:tile", ops = "%in%", values = tiles)

    # making the request
    items_info <- rstac_query %>% rstac::post_request(...)

    # progress bar status
    pgr_fetch  <- FALSE

    # if more than 1000 items are found the progress bar is displayed
    if (rstac::items_matched(items_info) > 1000)
        pgr_fetch <- TRUE

    # fetching all the metadata
    items_info <- items_info %>% rstac::items_fetch(progress = pgr_fetch)

    return(items_info)
}
#' @title Create a group of items
#' @name .sits_stac_group
#' @keywords internal
#'
#' @param items  a \code{STACItemCollection} object returned by rstac package.
#' @param fields a \code{character} vector with the names of fields to be
#'  grouped.
#'
#' @return       a \code{list} in which each index corresponds to a group with
#'  its corresponding \code{STACItemCollection} objects.
.sits_stac_group <- function(items, fields) {

    # grouping the items according to fields provided
    items_grouped <- rstac::items_group(items  = items,
                                        fields = fields)

    # adding a tile attribute in the root
    items_grouped <- purrr::map(items_grouped, function(x) {
        x$tile <- rstac::items_reap(x, fields = fields)[[1]]

        # resolution
        x$xres <- x$features[[1]]$properties[["eo:gsd"]]
        x$yres <- x$features[[1]]$properties[["eo:gsd"]]

        # size raster
        attrib <- "bdc:raster_size"
        if (is.null(x$features[[1]]$assets[[1]][[attrib]]))
            attrib <- "raster_size"
        x$ncols <- x$features[[1]]$assets[[1]][[attrib]]$x
        x$nrows <- x$features[[1]]$assets[[1]][[attrib]]$y

        return(x)
    })

    return(items_grouped)
}
#' @title Get bbox and intersects parameters
#' @name .sits_stac_roi
#' @keywords internal
#'
#' @param roi  the "roi" parameter defines a region of interest. It can be
#'  an \code{sfc} or \code{sf} object from sf package, a \code{character} with
#'  GeoJSON following the rules from RFC 7946, or a \code{vector}
#'  bounding box \code{vector} with named XY values
#'  ("xmin", "xmax", "ymin", "ymax").
#'
#' @return     A named \code{list} with the values of the intersection and bbox
#'             parameters. If bbox is supplied, the intersection parameter gets
#'             NULL, otherwise bbox gets NULL if intersects is specified.
.sits_stac_roi <- function(roi) {

    # list to store parameters values
    roi_list <- list()

    # verify the provided parameters
    if (!("sf" %in% class(roi))) {
        if (all(c("xmin", "xmax","ymin", "ymax") %in% names(roi)))
            roi_list[c("bbox", "intersects")] <- list(roi, NULL)

        else if (typeof(roi) == "character")
            roi_list[c("bbox", "intersects")] <- list(NULL, roi)
    } else {
        roi_list[c("bbox", "intersects")] <- list(as.vector(sf::st_bbox(roi)),
                                                  NULL)
    }

    # checks if the specified parameters names is contained in the list
    assertthat::assert_that(!purrr::is_null(names(roi_list)),
                            msg = "invalid definition of ROI")

    return(roi_list)
}
#' @title Datetime format
#' @name .sits_stac_datetime
#' @keywords internal
#'
#' @param start_date a \code{character} corresponds to the initial date when the
#'  cube will be created.
#' @param end_date   a \code{character} corresponds to the final date when the
#'  cube will be created.
#'
#' @return      a \code{character} formatted as parameter to STAC requisition.
.sits_stac_datetime <- function(start_date, end_date) {

    # ensuring that start_date and end_date were provided
    assertthat::assert_that(all(!purrr::is_null(start_date),
                                !purrr::is_null(end_date)),
                            msg = paste("sits_cube: for STAC_CUBE start_date",
                                        "and end_date must be provided"))

    # adding the dates according to RFC 3339
    datetime <- paste(start_date, end_date, sep = "/")

    return(datetime)
}

#' @title Format assets
#' @name .sits_stac_items_info
#' @keywords internal
#'
#' @param items a \code{STACItemCollection} object returned by rstac package.
#' @param bands a \code{character} with the bands names to be filtered.
#'
#' @return      a \code{tibble} with date, band and path information, arranged
#'  by the date.
.sits_stac_items_info <- function(items, bands) {

    assets_info <- rstac::assets_list(items, assets_names = bands) %>%
        tibble::as_tibble() %>% dplyr::arrange(date)

    return(assets_info)
}
#' @title Get the metadata values from STAC.
#' @name .sits_config_stac_values
#' @keywords internal
#'
#' @param collection_info a \code{STACCollection} object returned by rstac.
#'  package.
#' @param bands           a \code{character} with the bands names to be
#'  filtered.
#'
#' @return                a \code{list} with the information of scale factors,
#'  missing, minimum, and maximum values.
.sits_config_stac_values <- function(collection_info, bands) {

    # filters by the index of the bands that correspond to the collection
    index_bands <-
        which(lapply(collection_info$properties$`eo:bands`,`[[`, c("name"))
              %in% bands)

    vect_values <- vector()
    list_values <- list()

    # creating a named list of the metadata values
    purrr::map(c("min", "max", "nodata", "scale"), function(field) {
        purrr::map(index_bands, function(index) {
            vect_values[collection_info$properties$`eo:bands`[[index]]$name] <<-
                as.numeric(collection_info$properties$`eo:bands`[[index]][[field]])
        })
        list_values[[field]] <<- vect_values
    })
    list_values
}
#' @title Get the STAC information corresponding to a bbox extent
#' @name .sits_stac_get_bbox
#' @keywords internal
#'
#' @param items_info      a \code{STACItemCollection} object returned by rstac
#' package.
#' @param collection_info a \code{STACCollection} object returned by rstac.
#'
#' @return  a \code{bbox} object from the sf package representing the tile bbox.
.sits_stac_get_bbox <- function(items_info, collection_info) {

    # get the extent points
    extent_points <- items_info$features[[1]]$geometry$coordinates[[1]]

    # create a polygon and transform the proj
    polygon_ext <- sf::st_polygon(list(do.call(rbind, extent_points)))
    polygon_ext <- sf::st_sfc(polygon_ext, crs = 4326) %>%
        sf::st_transform(., collection_info[["bdc:crs"]])

    bbox_ext <- sf::st_bbox(polygon_ext)

    return(bbox_ext)
}
#' @title Get the STAC information corresponding to a tile.
#' @name .sits_stac_tile_cube
#' @keywords internal
#'
#' @param url             a \code{character} representing URL for the BDC STAC.
#' @param name            a \code{character} representing the output data cube.
#' @param collection_info a \code{STACCollection} object returned by rstac.
#' @param items_info      a \code{STACItemCollection} object returned by rstac.
#' @param cube            a \code{character} with name input data cube in BDC.
#' @param file_info       a \code{tbl_df} with the information from STAC.
#'
#' @return                a \code{tibble} with metadata information about a
#'  raster data set.
.sits_stac_tile_cube <- function(url,
                                 name,
                                 collection_info,
                                 items_info,
                                 cube,
                                 file_info){

    # obtain the timeline
    timeline <- unique(lubridate::as_date(file_info$date))

    # set the labels
    labels <- c("NoClass")

    # obtain bbox extent
    bbox_params <- .sits_stac_get_bbox(items_info, collection_info)

    # get the bands
    bands <- unique(file_info$band)

    # get scale factors, missing, minimum, and maximum values
    metadata_values  <- .sits_config_stac_values(collection_info, bands)

    # create a tibble to store the metadata
    cube <- .sits_cube_create(type      = "BDC_STAC",
                              URL       = url,
                              satellite = collection_info$properties$platform,
                              sensor    = collection_info$properties$instruments,
                              name      = name,
                              cube      = cube,
                              tile      = items_info$tile,
                              bands     = collection_info$bands,
                              labels    = labels,
                              scale_factors  = metadata_values$scale,
                              missing_values = metadata_values$nodata,
                              minimum_values = metadata_values$min,
                              maximum_values = metadata_values$max,
                              timelines = list(timeline),
                              nrows     = items_info$nrows,
                              ncols     = items_info$ncols,
                              xmin      = bbox_params$xmin[[1]],
                              xmax      = bbox_params$xmax[[1]],
                              ymin      = bbox_params$ymin[[1]],
                              ymax      = bbox_params$ymax[[1]],
                              xres      = items_info$xres,
                              yres      = items_info$yres,
                              crs       = collection_info[["bdc:crs"]],
                              file_info = file_info)

    return(cube)
}
