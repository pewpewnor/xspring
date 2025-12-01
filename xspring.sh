#!/bin/bash

# requirements to run this program:
# - unbuffer (install package 'expect' from your package manager),
#   this is so that text output colors are preserved during tee
# - mvn (apache maven) in PATH

life_cycle_args=""
module_build_flag=""
skip_tests_flag="-DskipTests"
run_flags=""
verbose_flag="-q"
extra_flags=""
test_specific_flag=""
log_file_name="xspring_log"

enable_incremental_build=false
enable_test_specific=false
enable_log_file=false
run_project=true

help_screen() {
	echo "Usage: $(basename "$0") [ARGUMENTS] [OPTIONS]"
	echo
	echo "Build, test, and run any Spring Boot project and using mvn and spring-boot:run"
	echo
	echo "Arguments:"
	echo "  i | install      Mode to do 'mvn install -DskipTests' before running the project"
	echo "  1 | incremental  Enable incremental build to only build modules that was modified since last build"
	echo "  c | clean        Mode to do 'mvn clean install -DskipTests' before running the project"
	echo "  b | build        Mode for 'mvn install -DskipTests' in order to only build the project"
	echo "  t | test         Mode to run a test for every next argument in the format '<class>#<method>'"
	echo "                   or test the entire project (won't fail if a module contains no tests)"
	echo "  <no args>        Run last build"
	echo
	echo "  generate-maven-project  Generate a new maven project interactively"
	echo
	echo "Options:"
	echo "  --warn         Show only WARN and ERROR level logs when running"
	echo "  --error        Show only ERROR level logs when running"
	echo "  -n | --no-run  Will only build the project and won't run it"
	echo "  --with-tests   Run tests when building the project, will fail if a module contains no tests"
	echo "  --verbose      Will also show the output logs when the project is being built"
	echo "  --log          Will log stdout and stderr to a file when running or testing"
	echo "  --date         When logging stdout and stderr to a file, name the file 'xspring_log_[date].txt' instead"
	echo "  --help         Display this help screen"
}

generate-maven-project() {
	echo -n "Group id / package import name (default='com.company.app'): "
	read group_id
	if [[ "$group_id" == "" ]]; then
		group_id="com.company.app"
	fi
	echo -n "Artifact id / project name (default='app'): "
	read artifact_id
	if [[ "$artifact_id" == "" ]]; then
		artifact_id="app"
	fi
	mvn archetype:generate -DgroupId="$group_id" -DartifactId="$artifact_id" -DarchetypeArtifactId=maven-archetype-quickstart -DarchetypeVersion=1.4 -DinteractiveMode=false
}

while [[ $# > 0 ]]; do
	case $1 in
	i | install)
		life_cycle_args="install"
		shift
		;;
	1 | incremental)
		enable_incremental_build=true
		shift
		;;
	c | clean)
		life_cycle_args="clean install"
		shift
		;;
	b | build)
		life_cycle_args="install"
		run_project=false
		shift
		;;
	t | test)
		enable_test_specific=true
		log_file_name="xspring_test_log"
		shift
		;;
	generate-maven-project)
		generate-maven-project
		exit
		;;
	--warn)
		run_flags="-Dspring-boot.run.arguments=--logging.level.root=WARN"
		shift
		;;
	--error)
		run_flags="-Dspring-boot.run.arguments=--logging.level.root=ERROR"
		shift
		;;
	--log)
		enable_log_file=true
		shift
		;;
	-n | --no-run)
		run_project=false
		shift
		;;
	--date)
		log_file_name="${log_file_name}_$(date)"
		shift
		;;
	--with-tests)
		life_cycle_args="test"
		skip_tests_flag=""
		verbose_flag=""
		shift
		;;
	--verbose)
		verbose_flag=""
		shift
		;;
	--help)
		help_screen
		exit 0
		;;
	--)
		$enable_test_specific=false
		shift
		;;
	*)
		if [[ $enable_test_specific == true ]]; then
			if [[ $test_specific_flag == "" ]]; then
				test_specific_flag="-Dtest=$1"
			else
				test_specific_flag="$test_specific_flag,$1"
			fi
		else
			extra_flags="$extra_flags $1"
		fi
		shift
		;;
	esac
done

# checks if the *app directory exists (such as myproject-app),
if [ -d *app ]; then # do not turn the [ ] into a [[ ]] since there is *
	# only recompile the modules that was changed according to git diff
	# and source code modify time > last build time
	if [[ "$enable_incremental_build" == true ]]; then
		if [ -f .idea/last_build_time ]; then
			last_build_time=$(cat .idea/last_build_time)
			already_checked_module=""
			while read line; do
				MODULE_FROM_LINE="$(echo "$line" | cut -d "/" -f1)"
				if [[ "$module_from_line" != "$already_checked_module" ]] &&
					[[ $(stat -c "%Y" "$line") -ge $last_build_time ]]; then
					if [[ $module_build_flag == "" ]]; then
						module_build_flag="-pl $module_from_line"
					else
						module_build_flag="$module_build_flag,$module_from_line"
					fi
					already_checked_module="$module_from_line"
				fi
			done < <({
				git diff --name-only --diff-filter=ACM
				git ls-files --others --exclude-standard
			} | sort)
		else
			# if no last_build_time file exists, then pretend like it's normal build all modules
			enable_incremental_build=false
		fi
	fi

	# if found, then that module is the thing that GETS executed like a springboot project
	run_flags="-pl *app $run_flags" # do not put '*app' in quotes
fi

incremental_build_found_nothing() {
	if [[ $enable_incremental_build == true ]] && [[ $module_build_flag == "" ]]; then
		return 0
	fi
	return 1
}

if [[ $enable_test_specific == true ]]; then
	mkdir -p .idea
	build_time_before_build="$(date +%s)"

	echo "mvn test $test_specific_flag $MODULE_BUILD_FLAG -DfailIfNoTests=false"
	if [[ $enable_log_file == true ]]; then
		echo "Specific Test Timestamp: $(date)" >"$log_file_name".txt
		unbuffer mvn test $test_specific_flag $module_build_flag -DfailIfNoTests=false 2>&1 | tee -a "$log_file_name".txt
	else
		unbuffer mvn test $test_specific_flag $module_build_flag -DfailIfNoTests=false
	fi

	if [[ $? == 0 ]]; then
		echo "$build_time_before_build" >.idea/last_build_time
	fi
else
	# BUILD
	if [[ "$life_cycle_args" != "" ]] && ! incremental_build_found_nothing; then
		mkdir -p .idea
		build_time_before_build="$(date +%s)"

		echo "mvn $life_cycle_args $module_build_flag $skip_tests_flag"
		unbuffer mvn $life_cycle_args $module_build_flag $skip_tests_flag

		if [[ $? == 0 ]]; then
			echo "$build_time_before_build" >.idea/last_build_time
		else
			run_project=false
		fi
	fi

	# run
	if [[ $run_project == true ]]; then
		echo "mvn spring-boot:run $run_flags $verbose_flag $extra_flags"
		if [[ $enable_log_file == true ]]; then
			echo "Log File Timestamp: $(date)" >"$log_file_name".txt
			unbuffer mvn spring-boot:run $run_flags $verbose_flag $extra_flags 2>&1 | tee -a "$log_file_name".txt
		else
			unbuffer mvn spring-boot:run $run_flags $verbose_flag $extra_flags
		fi
	fi
fi
