# The main controlling code for **hubstats**
"use strict"

# ## Set
# A simple set abstraction
class Set
  # ### Return whether this set contains a key.
  contains: (key) ->
    key of @

  # ### Add a key to the set.
  insert: (key) ->
    @[key] = undefined

  # ### Remove a key from the set.
  remove: (key) ->
    delete @[key]

# ## Internal constants
BASE_URL = "https://github.com"

# ## Internal state

# ### Cached selections
status = null
loginLink = null
repoLink = null
repoForm = null
loginInput = null
repoInput = null
repoFormInput = null

# ### The current chart instance
chart = null

# ### A `Network` instance for the current request
network = null

# ### Backing storage for the chart
data =
  commits: []
  dirty: false

  # Remove all stored commits.
  clear: ->
    @commits = []
    @dirty = true
    return

  # Add a commit.
  push: (commit) ->
    @commits.push commit
    @dirty = true
    return

# ## Internal functions

# ### Update the interface to reflect the current status
showStatus = (msg, pending=true) ->
  status.text msg
  repoFormInput
    .attr("disabled", pending)

  return

# ### Handle a network status event
sinkStatus = (event) ->
  switch event.type
    when "meta"
      showStatus "Received metadata..."
    when "commit"
      showStatus "Received commit #{event.n} of #{event.total}..."

  return

# ### Handle a network error
# jQuery doesn't provide the actual status code due to cross-site scripting
# issues with JSON-P, so all errors show the same message.
sinkError = ->
  showStatus "An error occurred or the data is still being generated. #{
    }Please try again in a few seconds.", false

  return

# ### Load data for the commits on `master` in a user's repository
loadData = (login, repo) =>
  showStatus "Loading..."

  data.clear()

  # Update the page heading.
  loginUrl = "#{BASE_URL}/#{login}"
  loginLink
    .attr("href", loginUrl)
    .text(login)

  repoUrl = "#{loginUrl}/#{repo}"
  repoLink
    .attr("href", repoUrl)
    .text(repo)

  # Set up the network.
  unless network? and network.login == login and network.repo == repo
    network = new Network(login, repo)
      .onError(sinkError)
      .onStatus(sinkStatus)

  # A set of IDs for unseen commits that are part of the current branch.
  expected = new Set()

  # Handle a commit.
  sinkCommit = (commit) ->
    id = commit.id

    # Add a commit to the data set if it's part of the current branch.
    if expected.contains id
      # Convert the date to local time. Date strings returned by the network
      # API are in Pacific Time.
      data.push
        t: new Date "#{commit.date.replace /-/g, " "} GMT-0800"

      # Update the expected set.
      expected.remove id
      for [parentId, time, space] in commit.parents
        expected.insert parentId

    return

  # Handle network metadata.
  sinkMeta = (meta) =>
    # Find the head for this user's `master` branch.
    for user in meta.users
      if user.name == login
        for head in user.heads
          if head.name == "master"
            masterId = head.id
            break
        break

    if masterId?
      # Get all commits on the `master` branch.
      expected.insert masterId
      network.eachCommit sinkCommit, -> showStatus "", false
    else
      showStatus "No master branch was found for this repository.", false

    return

  # Request repository information.
  network.getMeta sinkMeta

  return

# ### Update the interface to reflect the current state
update = ->
  if data.dirty
    # Re-draw the chart and clear the dirty flag.
    d3.select("#chart")
      .datum(data.commits)
      .call(chart)

    data.dirty = false

  return

# ## Run when the DOM is ready
$ ->
  # Cache selections for later use.
  status = $ "#status"
  loginLink = $ "#loginLink"
  repoLink = $ "#repoLink"
  repoForm = $ "#repoForm"
  loginInput = repoForm.find "input[name=\"login\"]"
  repoInput = repoForm.find "input[name=\"repo\"]"
  repoFormInput = repoForm.find "input"

  # Set up the chart.
  chart = calendarHeatmap()
    # Each data point represents a single commit.
    .z(-> 1)

  # Set up a handler for form submission.
  repoForm.submit (event) ->
    # Prevent the form from being submitted.
    event.preventDefault()

    # Load the data.
    loadData loginInput.val(), repoInput.val()

    return

  # Set up a timer for updating the interface.
  setInterval update, 1500

  # Load data for the default repository.
  loadData "anthonyde", "hubstats"

  return
