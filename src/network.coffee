# A simplified interface for interacting with GitHub's [Secret Network API] [1]
# (see `_posts/2010-04-23-network.markdown`)
#
#   [1]: https://github.com/github/develop.github.com
"use strict"

# ## Internal constants
BASE_URL = "https://github.com"

# # Network
# A [jQuery] [1]-based network API wrapper
#
#   [1]: http://jquery.com/ "jQuery"
class @Network
  # ## Internal helper functions

  # ### Send a JSON-P request
  # `success` is called with the returned data if the request is successful,
  # otherwise `error` is called.
  queryJSONP = (url, success, error) ->
    $.ajax url,
      # JSON-P requests are not cached by default.
      cache: true
      dataType: "jsonp"
      error: -> error()
      success: (data) -> success data
      timeout: 5000

    return

  # ### Request network metadata for a repository
  queryNetworkMeta = (login, repo, success, error) ->
    url = "#{BASE_URL}/#{login}/#{repo}/network_meta"
    queryJSONP url, success, error
    return

  # ### Request a network data chunk for a repository
  queryNetworkData = (login, repo, nethash, start, end, success, error) ->
    url = "#{BASE_URL}/#{login}/#{repo}/network_data_chunk?nethash=#{nethash
      }&start=#{start}&end=#{end}"
    queryJSONP url, success, error
    return

  # ## Configuration

  # ### Initialize a new class instance
  # Commit responses are cached to avoid sending unnecessary requests.
  constructor: (@login, @repo) ->
    @error = null
    @status = null
    @nethash = null
    @commits = null

  # ### Get or set the error callback
  # The error callback is called when an error occurs during a request.
  onError: (x) ->
    if !arguments.length then @error else @error = x; @

  # ### Get or set the status callback
  # The status callback is called when a status event occurs.
  onStatus: (x) ->
    if !arguments.length then @status else @status = x; @

  # ## Instance methods

  # ### Get the metadata for this network
  # This function executes a callback with the network metadata, invalidating
  # the commit cache if the network has changed.
  getMeta: (callback) ->
    # Handle a metadata response.
    sinkMeta = (meta) =>
      @status?(
        type: "meta"
      )

      # Invalidate the cache if the nethash has changed.
      unless @nethash == meta.nethash
        @nethash = meta.nethash
        @commits = null

      callback meta

      return

    # Request the metadata.
    queryNetworkMeta @login, @repo, sinkMeta, => @error?()

    return

  # ### Execute a callback for each commit in the network
  # `commit` is called with each commit in reverse topological order.
  # `success` is called when all commits have been processed.
  #
  # This function assumes that the commits returned by the server are
  # contiguous and in topological order.
  eachCommit: (commit, success) ->
    if @commits?
      # The `commit` callback expects commits in reverse topological order.
      for d in @commits.slice(0).reverse()
        commit d

      success()

    else
      # Get information needed to request network data.
      @getMeta (meta) =>
        nCommits = 0
        totalCommits = meta.dates.length

        nethash = meta.nethash
        focus = totalCommits - 1

        # Request the remaining commits. The maximum number of commits (100)
        # are requested at a time.
        queryRest = =>
          # `start` and `end` times for a chunk are inclusive.
          start = if focus > 99 then focus - 99 else 0
          end = focus

          # Set the focus to the next unseen commit.
          focus = start - 1

          queryNetworkData @login, @repo, nethash, start, end, sinkData, =>
            @error?()

          return

        # Handle a network data response, executing the callback for each
        # commit and requesting the remaining data.
        sinkData = (data) =>
          commits = data.commits

          @status?(
            type: "commit"
            n: nCommits += commits.length
            total: totalCommits
          )

          # The `commit` callback expects commits in reverse topological order.
          for d in commits.slice(0).reverse()
            # Store commits in the cache as they are dispatched.
            commit (@commits ?= [])[d.time] = d

          unless focus < 0
            queryRest()
          else
            success()

          return

        queryRest()

        return

    return
