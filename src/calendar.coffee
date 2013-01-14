# A [D3] [1]-based calendar heatmap for visualizing discrete-time data sets
#
# This chart is inspired by Mike Bostock's [Calendar View] [2] and a
# [poster] [3] by Rick Wicklin and Robert Allison.
#
#   [1]: http://d3js.org/ "D3"
#   [2]: http://bl.ocks.org/4063318 "Calendar View"
#   [3]: http://stat-computing.org/dataexpo/2009/posters/wicklin-allison.pdf
#          "Congestion in the Sky"
"use strict"

# ## Internal constants
DAY_ABBREVIATIONS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
MONTH_ABBREVIATIONS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug",
  "Sep", "Oct", "Nov", "Dec"]

# A year has 52.14 weeks on average, but some years (such as 1972 and 2000)
# have days in up to 54 weeks.
AVG_WEEKS = 52.14
MAX_WEEKS = 54

N_MONTHS = 12

N_WEEKDAYS = 7

# ## Internal helper functions

# ### Force an update of an element's style
# This function implements a workaround for a bug in Firefox ([#701626] [1])
# that causes CSS transitions to immediately display the final state if an
# animated property is changed before the initial state is computed. Other
# browsers are not affected.
#
#   [1]: https://bugzil.la/701626 "Bugzilla@Mozilla - Bug 701626"
flushStyle = (elem) ->
  window.getComputedStyle(elem).display
  return

# ### Register a `transitionend` event handler for the current element
onCssTransitionEnd = (f) ->
  @addEventListener "transitionend", f
  @addEventListener "webkitTransitionEnd", f
  @

# ### Fade a D3 selection in
# The selected elements must have a CSS transition configured for `opacity`.
fadeIn = (selection) ->
  selection
    .style("opacity", 0)
    .each(->
      # Force a style update to guarantee that the transition is shown
      flushStyle @
      @style.opacity = 1
      return
    )

# ### Fade a D3 selection out and remove it
# The selected elements must have a CSS transition configured for `opacity`.
fadeOut = (selection) ->
  selection
    .style("opacity", 0)
    .each(->
      onCssTransitionEnd.call @, -> @parentNode?.removeChild @
      return
    )

# ### Date formatting functions
formatDate = d3.time.format "%Y-%m-%d"
formatWeek = d3.time.format "%U"
getWeek = (t) -> +formatWeek t
formatDayOfMonth = d3.time.format "%d"
getDayOfMonth = (t) -> +formatDayOfMonth t
formatDayOfWeek = d3.time.format "%w"
getDayOfWeek = (t) -> +formatDayOfWeek t

# # Calendar Heatmap
# This implementation is based on the reusable chart convention at
# <http://bost.ocks.org/mike/chart/>.
@calendarHeatmap = ->
  # ## Default configuration
  z = (d) -> d.z

  colorScale = d3.scale.linear()
    .interpolate(d3.interpolateHcl)
    .range(["#e0ecf4", "#4d004b"])

  # ## Implementation
  chart = (selection) ->
    # ### Layout constants
    WIDTH = 960 # px
    CELL_SIZE = 14 # px

    TOP_MARGIN = 1.5 * CELL_SIZE
    MONTH_PADDING = CELL_SIZE
    YEAR_LABEL_OFFSET = 3 * CELL_SIZE
    WEEK_HEIGHT = N_WEEKDAYS * CELL_SIZE

    # ### Animation constants
    defaultDuration = 1000 # ms
    resizeDuration = defaultDuration
    slideDuration = defaultDuration

    # ### Get the y-coordinate for year `i`
    yearY = (i) -> (WEEK_HEIGHT + MONTH_PADDING) * i

    # `data` is an array of objects, each with the following properties:
    #
    # * `t0`: A `Date` object
    # * `z`: A number
    selection.each (data) ->
      # ### Convert the data to an internal representation
      # Data is stored in a hierarchy of years, months, and days.
      #
      # `years` is an array of objects, each with the following properties:
      #
      # * `t0`: A `Date` object for the beginning of the year
      # * `months`: An array of objects
      #
      # Objects in each `months` array have the following properties:
      #
      # * `t0`: A `Date` object for the beginning of the month
      # * `days`: An array of objects
      #
      # Objects in each `days` array have the following properties:
      #
      # * `t0`: A `Date` object for the beginning of the day
      # * `z`: The sum of all z-values for the day
      years = {}

      for d in data
        t = d.t
        y0 = t.getFullYear()
        m0 = t.getMonth()
        d0 = getDayOfMonth t

        t0 = new Date y0, 0, 1
        year = years[+t0] ?=
          t0: t0
          months: {}

        t0 = new Date y0, m0, 1
        month = year.months[+t0] ?=
          t0: t0
          days: {}

        t0 = new Date y0, m0, d0
        day = month.days[+t0] ?=
          t0: t0
          z: 0

        # Accumulate the z-value for this day.
        day.z += z d

      # Flatten the year, month, and day mappings into arrays.
      for year in years = d3.values years
        for month in year.months = d3.values year.months
          month.days = d3.values month.days

      # ### Update the chart

      # Prepare the data for binding.
      if years.length > 0
        # Sort the years to display them in order.
        years.sort (a, b) -> a.t0 - b.t0

        # Set up the color scale.
        zMin = d3.min years, (d) ->
          d3.min d.months, (d) ->
            d3.min d.days, (d) ->
              d.z

        zMax = d3.max years, (d) ->
          d3.max d.months, (d) ->
            d3.max d.days, (d) ->
              d.z

        colorScale.domain([zMin, zMax])

        data = [[years]]
      else
        data = []

      # Update the SVG element.
      svg = d3.select(@).selectAll("svg")
        .data(data)

      svg.enter()
        .append("svg")
        .attr("height", 0)
        .attr("width", WIDTH)

      svg
        .transition()
          .duration(resizeDuration)
          .ease("linear")
          # Use a custom tween function to ensure that years are visible during
          # enter/exit transitions.
          .attrTween("height", (d, i, h0) ->
            # Don't account for the height of the month labels unless they are
            # visible.
            h1 = if d.length > 0 then TOP_MARGIN + MONTH_PADDING +
              yearY d[0].length else 0

            if h0? and h0 > h1
              (t) -> if t < 1 then h0 else h1
            else
              (t) -> h1
          )

      # Update the main group.
      g = svg.selectAll(".calendar")
        .data(Object, (d) -> 1)

      gEnter = g.enter()
        .append("g")
          .attr("class", "calendar")
          # Center years horizontally.
          .attr("transform", "translate(#{(WIDTH - MAX_WEEKS * CELL_SIZE) / 2
            },#{TOP_MARGIN + MONTH_PADDING})")
          .call(fadeIn)

      # Add a label for each month.
      gEnter
        .append("g")
          .attr("transform", "translate(0,#{-MONTH_PADDING})")
          .selectAll("text")
            .data(MONTH_ABBREVIATIONS).enter()
              .append("text")
                .attr("class", "month-label")
                # `text-anchor` is `middle` for this element, so offset the
                # label by half a month to center it.
                .attr("x", (d, i) ->
                  (i + .5) / N_MONTHS * AVG_WEEKS * CELL_SIZE
                )
                .text(String)

      g.exit()
        .call(fadeOut)

      # Update the legend.
      legendScale = d3.scale.linear()
        .domain([0, WEEK_HEIGHT])
        .rangeRound([zMax, zMin])

      legendInverseScale = d3.scale.linear()
        .domain(legendScale.range())
        .range(legendScale.domain())

      legend = g.selectAll(".legend")
        # Don't draw the legend unless multiple colors are displayed.
        .data(if zMin != zMax then [1] else [])

      legendEnter = legend.enter()
        .append("g")
          .attr("class", "legend")
          .attr("transform",
            "translate(#{MAX_WEEKS * CELL_SIZE + MONTH_PADDING})")
          .call(fadeIn)

      legend.exit()
        .call(fadeOut)

      # Update the legend color scale. The scale consists of colored `rect`
      # elements for every color in the range of the chart.
      legendColor = legend.selectAll("rect")
        .data(d3.range WEEK_HEIGHT + 1)

      legendColor.enter()
        .append("rect")
          .attr("width", CELL_SIZE)
          .attr("height", 1)
          .attr("y", Number)

      legendColor
        .style("fill", (d) -> colorScale legendScale d)

      legendColor.exit()
        .remove()

      # Update the legend axis.
      legendAxis = d3.svg.axis()
        .scale(legendInverseScale)
        .orient("right")
        # Show around five ticks on integer values.
        .ticks(Math.min 5, zMax - zMin)

      legendEnter
        .append("g")
          .attr("class", "axis")
          .attr("transform", "translate(#{CELL_SIZE})")
          # The domain path isn't created on the first update unless this is
          # called on enter.
          .call(legendAxis)

      legend.selectAll(".axis")
        .transition()
          .duration(defaultDuration)
          .call(legendAxis)

      # Update each year group.
      year = g.selectAll(".year")
        .data(Object, (d) -> +d.t0)

      year.enter()
        .append("g")
          .attr("class", "year")
          # Place years far left for the slide-in transition.
          .attr("transform", (d, i) -> "translate(#{-WIDTH / 2},#{yearY i})")
          .call((selection) ->
            # Add the year label.
            selection
              .append("text")
                .attr("class", "year-label")
                .attr("x", -YEAR_LABEL_OFFSET - MONTH_PADDING)
                .attr("y", CELL_SIZE / 2)
                .text((d) -> d.t0.getFullYear())

            # Add a label for each day of the week.
            weekday = selection
              .append("g")
                .attr("transform",
                  "translate(#{-MONTH_PADDING},#{CELL_SIZE / 2})")
                .selectAll("text")
                  .data(DAY_ABBREVIATIONS)

            weekday.enter()
              .append("text")
                .attr("y", (d, i) -> WEEK_HEIGHT - (i + 1) * CELL_SIZE)
                .text(String)

            return
          )
          .call(fadeIn)

      year
        .transition()
          .duration(slideDuration)
          .attr("transform", (d, i) -> "translate(0,#{yearY i})")

      year.exit()
        .call(fadeOut)

      # Update each month group.
      month = year.selectAll(".month")
        .data(((d) -> d.months), (d) -> +d.t0)

      month.enter()
        .append("g")
          .attr("class", "month")
          # Add month decorations.
          .each((d) ->
            selection = d3.select(@)

            # The `day` parameter of the `Date` constructor is interpreted
            # such that 1 represents the first day of the month. `t1` is
            # generated with a `day` of 0 to get the last day of the month,
            # eliminating the need to account for months ending on the first
            # week of the next year.
            t0 = d.t0
            t1 = new Date t0.getFullYear(), t0.getMonth() + 1, 0
            w0 = getWeek t0
            w1 = getWeek t1
            d0 = getDayOfWeek t0
            d1 = 1 + getDayOfWeek t1

            # Generate a path for the inner borders.
            path = []

            # Generate horizontal (day) lines.
            for d in [N_WEEKDAYS - 2..0]
              m = "M #{(+(d0 > d) + w0) * CELL_SIZE} #{
                }#{WEEK_HEIGHT - (d + 1) * CELL_SIZE}"
              h = "H #{(+(d1 > d + 1) + w1) * CELL_SIZE}"
              path.push m, h

            # Generate vertical (week) lines.
            path.push "M #{(w0 + 1) * CELL_SIZE} 0",
              "V #{WEEK_HEIGHT - d0 * CELL_SIZE}"

            v = "V #{WEEK_HEIGHT}"

            for w in [w0 + 2..w1 - 1]
              m = "M #{w * CELL_SIZE} 0"
              path.push m, v

            path.push "M #{w1 * CELL_SIZE} #{WEEK_HEIGHT - d1 * CELL_SIZE}",
              "V #{WEEK_HEIGHT}"

            # Add the path for the internal borders.
            selection
              .append("path")
                .attr("class", "internal")
                .attr("d", path.join " ")

            # Add a path for the outline.
            selection
              .append("path")
                .attr("class", "outline")
                .attr("d", "M #{w0 * CELL_SIZE} 0 #{
                  }H #{w1 * CELL_SIZE} #{
                  }V #{WEEK_HEIGHT - d1 * CELL_SIZE} #{
                  }H #{(w1 + 1) * CELL_SIZE} #{
                  }V #{WEEK_HEIGHT} #{
                  }H #{(w0 + 1) * CELL_SIZE} #{
                  }V #{WEEK_HEIGHT - d0 * CELL_SIZE} #{
                  }H #{w0 * CELL_SIZE} #{
                  }Z")

            return
          )
          .call(fadeIn)

      month.exit()
        .call(fadeOut)

      # Update each day group.
      day = month.selectAll(".day")
        .data(((d) -> d.days), (d) -> +d.t0)

      day.enter()
        # Use `insert` to keep the month paths on top.
        .insert("rect", "path")
          .attr("class", "day")
          .attr("width", CELL_SIZE)
          .attr("height", CELL_SIZE)
          .attr("x", (d) -> (getWeek d.t0) * CELL_SIZE)
          .attr("y", (d) -> WEEK_HEIGHT - (1 + getDayOfWeek d.t0) * CELL_SIZE)
          .call(fadeIn)
          .append("title")

      day
        .style("fill", (d) -> colorScale d.z)
        .select("title")
          .text((d) -> "#{formatDate d.t0}: #{d.z}")

      day.exit()
        .call(fadeOut)

    return

  # ## Configuration

  # ### Get or set the z-value accessor.
  chart.z = (x) ->
    if !arguments.length then z else z = x; chart

  # ### Get or set the color scale.
  chart.colorScale = (x) ->
    if !arguments.length then colorScale else colorScale = x; chart

  chart
