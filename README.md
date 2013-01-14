# GitHub Repository Statistics

**hubstats** is a statistics viewer for GitHub repositories built with
[D3](http://d3js.org/) and [jQuery](http://jquery.com/). It is written in
[CoffeeScript](http://coffeescript.org/), a language that compiles to
JavaScript.

This revision displays a calendar heatmap of all commit activity over the
lifetime of a repository. More visualizations and settings will be added in
the future.

[View the latest revision online.](http://anthonyde.github.com/hubstats/)

## Development

GNU Make 3.8 or later and CoffeeScript 1.4.0 are required to build this
project. Some build tasks have additional dependencies.

### Getting the code

To get a local copy of the code, clone it using git:

    $ git clone git://github.com/anthonyde/hubstats.git
    $ cd hubstats

### Building

To build all source files:

    $ make all

or

    $ make

This will create a `build` directory containing the generated JavaScript files
along with the CSS and HTML files for the project.

### Building the documentation

To generate annotated source for all CoffeeScript files:

    $ make doc

This requires [docco](http://jashkenas.github.com/docco/) and its
prerequisites to be installed. A `build/doc` directory will be created
containing the generated documentation.

### Style checking

To run code style checks:

    $ make check

This requires [coffeelint](http://www.coffeelint.org/). Any errors should be
resolved before committing. Warnings should be avoided whenever reasonably
possible.

### Testing

To test a build locally:

    $ make serve

This requires Python 2.7. A HTTP server will be launched that serves the
contents of the `build` directory on port 8000.

### Updating GitHub Pages

To update the `gh-pages` branch from the current branch:

    $ make gh-pages

This will build the source and documentation on the current branch if
necessary, switch to the `gh-pages` branch, add the generated files to the
project root directory, and initiate a new commit.

## Contributing

Feel free to submit bug reports, feature requests, and pull requests to the
[issue tracker](https://github.com/anthonyde/hubstats/issues) on GitHub.

Pull requests should use one topic branch per feature and each commit should
pass `make check` without errors and use conventions that match the rest of
the code.

## License

This project is released under the BSD-3 license. See the file `LICENSE`.
