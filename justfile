PORT := "8009"

SCRATCH_DIR := "scratch"

# source directories
APP_SRC_DIR := "web/frontend/app"
SCRIPT_DIR := "web/frontend/script"
STYLE_DIR := "web/frontend/style"

# dist directories
DIST_DIR := "dist"
APP_ROOT := "app"

@_install_crate name:
    cargo install --force {{name}}

@_check_rust_crate name:
    type {{name}} >/dev/null 2>&1 || just _install_crate {{name}}

@_check_dep name:
    type {{name}} >/dev/null 2>&1 || { echo "Missing dependency '{{name}}'"; exit 1; }

# Check & try to install missing dependencies
check-deps:
    @just _check_dep cargo
    @just _check_dep rustup

    @just _check_rust_crate watchexec
    @just _check_rust_crate wasm-pack
    @just _check_rust_crate microserver

    @just _check_dep rsync

    @just _check_dep npm
    @just _check_dep npx
    @just _check_dep sass

    @just _check_dep sass

# Initialize the project after cloning
init:
    npm install
    rustup update
    rustup target add wasm32-unknown-unknown
    just check-deps

# Run tests; args for web app environment
test +args:
    cd {{APP_SRC_DIR}} && wasm-pack test {{args}}
    cd {{APP_SRC_DIR}} && cargo test

# Run cargo with custom arguments
cargo +args:
    cd {{APP_SRC_DIR}} && cargo {{args}}

# Clean up output directories
clean:
    rm -Rf {{DIST_DIR}}
    rm -Rf {{SCRATCH_DIR}}

# Clean up build & output directories
clean-all: clean
    rm -Rf {{APP_SRC_DIR}}/target
    rm -Rf {{APP_SRC_DIR}}/pkg

# Create scratch directory
@mkscratch:
    mkdir -p {{SCRATCH_DIR}}

# Create distributable directory
@mkdist:
    mkdir -p {{DIST_DIR}}
    mkdir -p {{DIST_DIR}}/{{APP_ROOT}}/static/style
    mkdir -p {{DIST_DIR}}/{{APP_ROOT}}

# Build scripts
build-scripts: mkdist mkscratch
    npx swc --presets @babel/preset-env -d {{DIST_DIR}}/{{APP_ROOT}}/static/script {{SCRIPT_DIR}}

# Build styles
build-styles: mkdist mkscratch
    sass {{STYLE_DIR}}/main.scss | npx cleancss > {{DIST_DIR}}/{{APP_ROOT}}/static/style/main.css

# Build frontend application
build-app: mkdist mkscratch
    cd {{APP_SRC_DIR}} && cargo build && wasm-pack build --target web --out-name package --dev && just _deploy-dev-app

# Build frontend application
build-app-release: mkdist mkscratch
    cd {{APP_SRC_DIR}} && cargo build --release && wasm-pack build --target web --out-name package

# Automatically rebuild scripts on change
watch-scripts:
    watchexec --watch {{SCRIPT_DIR}} --exts js just build-scripts

# Automatically rebuild styles on change
watch-styles:
    watchexec --watch {{STYLE_DIR}} --exts scss,sass,css just build-styles

# Automatically rebuild frontend app on change
watch-app:
    watchexec --watch {{APP_SRC_DIR}} --exts rs,toml,html just build-app

@_deploy-dev-app:
    rsync -ahxv {{APP_SRC_DIR}}/pkg {{DIST_DIR}}/{{APP_ROOT}}
    rsync -ahxv {{APP_SRC_DIR}}/index.html {{DIST_DIR}}/{{APP_ROOT}}/index.html

# Copy static assets
copy-assets: mkdist mkscratch
    rsync -ahxv unit/*.service {{DIST_DIR}}/unit/
    rsync -ahxv web/webroot/* {{DIST_DIR}}/{{APP_ROOT}}/webroot/

# Run a development server
devserver: clean mkdist mkscratch copy-assets
    #!/bin/sh
    # Propagate CTRL+C to all background processes.
    trap "exit" INT TERM ERR
    trap "kill 0" EXIT

    just watch-scripts &
    just watch-styles &
    just watch-app &
    microserver --port {{PORT}} {{DIST_DIR}}/{{APP_ROOT}}

    # Wait for all background processes to terminate.
    wait

# Build the project in release mode
build-release: clean mkdist mkscratch copy-assets build-scripts build-styles build-app-release
    # build in release mode
