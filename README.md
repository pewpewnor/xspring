# xspring

A Bash helper for building, testing, and running Maven-based Spring Boot
projects from the terminal. It wraps common Maven workflows and offers options
for clean or incremental builds, running selected tests, filtering runtime logs,
and writing logs to a file. It can also generate a basic Maven project.

## Requirements

- Bash
- Apache Maven available as `mvn`
- `unbuffer` from the `expect` package to preserve colored output through the
script

## Use

Make the script executable once, then invoke it from the root of a Maven
project:

~~~sh
chmod +x xspring.sh
./xspring.sh --help
./xspring.sh
~~~

Examples:

~~~sh
./xspring.sh clean
./xspring.sh build --no-run
./xspring.sh test MyServiceTest#shouldSave
./xspring.sh --warn --log
~~~

The default mode runs the last build. The script operates on the Maven project
in the current working directory.
