scratch_dir := "scratch"

# build directories
frontend_app_build_dir := "web/frontend/app"

# dist directories
dist_dir := "dist"
app_root := "app"

@_check_dep name:
    type {{name}} >/dev/null 2>&1 || echo "Missing '{{name}}'"

# List missing build dependencies
check-deps:
    @echo Checking dependencies...
    @just _check_dep npm
    @just _check_dep npx
    @just _check_dep cargo
    @just _check_dep sass
    @just _check_dep watchexec
    @just _check_dep rsync
    @just _check_dep rustup
    @cargo make --help >/dev/null 2>&1 || echo "Missing 'cargo make'"
    @echo done

# Initialize the project after cloning
init:
    npm install
    rustup update
    rustup target add wasm32-unknown-unknown
    cargo install --force cargo-make

# Run tests
test:
    # commands to test code go here

# Run cargo with custom arguments
cargo +args:
    cd {{frontend_app_build_dir}} && cargo {{args}}

# Clean up output directories
clean:
    rm -Rf {{dist_dir}}
    rm -Rf {{scratch_dir}}

# Clean up build & output directories
clean-all: clean
    rm -Rf {{frontend_app_build_dir}}/target
    rm -Rf {{frontend_app_build_dir}}/pkg

# Create scratch directory
@mkscratch:
    mkdir -p {{scratch_dir}}

# Create distributable directory
@mkdist:
    mkdir -p {{dist_dir}}
    mkdir -p {{dist_dir}}/{{app_root}}/static/style
    mkdir -p {{dist_dir}}/{{app_root}}

# Build scripts
build-scripts: mkdist mkscratch
    # commands to build scripts go here

# Build styles
build-styles: mkdist mkscratch
    sass web/frontend/style/main.scss | npx cleancss > {{dist_dir}}/{{app_root}}/static/style/main.css

# Build frontend application
build-app: mkdist mkscratch
    cd {{frontend_app_build_dir}} && cargo make build

# Automatically rebuild scripts on change
watch-scripts:
    watchexec --watch web/frontend --exts js just build-scripts

# Automatically rebuild styles on change
watch-styles:
    watchexec --watch web/frontend --exts scss,sass,css just build-styles

@_deploy-dev-app:
    rsync -ahxv {{frontend_app_build_dir}}/pkg {{dist_dir}}/{{app_root}}
    rsync -ahxv {{frontend_app_build_dir}}/index.html {{dist_dir}}/{{app_root}}/index.html

# Automatically rebuild frontend app on change
watch-app:
    just cargo make watch

# Copy static assets
copy-assets: mkdist mkscratch
    rsync -ahxv unit/*.service {{dist_dir}}/unit/
    rsync -ahxv web/webroot/* {{dist_dir}}/{{app_root}}/webroot/

# Run a development server
devserver: clean mkdist mkscratch copy-assets
    #!/bin/sh
    # Propagate CTRL+C to all background processes.
    trap "exit" INT TERM ERR
    trap "kill 0" EXIT

    just watch-scripts &
    just watch-styles &
    just watch-app &
    just cargo make serve

    # Wait for all background processes to terminate.
    wait

# Build the project in release mode
build-release: clean mkdist mkscratch copy-assets build-scripts build-styles build-app
    # commands to build in release mode go here

