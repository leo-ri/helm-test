#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

DEFAULT_CHART_RELEASER_VERSION=v1.2.1

show_help() {
cat << EOF
Usage: $(basename "$0") <options>

    -h, --help               Display help
    -v, --version            The chart-releaser version to use (default: $DEFAULT_CHART_RELEASER_VERSION)"
        --config             The path to the chart-releaser config file
    -d, --charts-dir         The charts directory (default: charts)
    -u, --charts-repo-url    The GitHub Pages URL to the charts repo (default: https://<owner>.github.io/<repo>)
    -o, --owner              The repo owner
    -r, --repo               The repo name
EOF
}

main() {
    local version="$DEFAULT_CHART_RELEASER_VERSION"
    local config=
    local charts_dir=charts
    local owner=
    local repo=
    local charts_repo_url=

    parse_command_line "$@"

    # : "${CR_TOKEN:?Environment variable CR_TOKEN must be set}" # TODO UNCOMMENT

    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    pushd "$repo_root" > /dev/null

    print_line
    echo 'Find all dependencies' #TODO it should be REMOTE DEPENDENCY. add it
    dependencies=($(awk '/dependencies:/,/name:/{print $0}' charts/*/Chart.yaml | awk -F : '/name/{print $2}'))
    local target_folders
    for dependency in "${dependencies[@]}"; do
        echo "found dependency: $dependency"
        folder_name=$(grep "^name: $dependency" charts/*/Chart.yaml | awk -F / '{print $2}')
        echo "dependency inside folder: $folder_name"
        #TODO this is look complicated
        if [[ -n "${target_folders:-}" ]]; then
            if [[ ! "${target_folders[*]}" =~  $folder_name ]]; then
                target_folders+=("$folder_name")
                echo "ECCHO CURRENT" "${target_folders[@]}"
            fi
        else
            target_folders+=("$folder_name")
            echo "INIT WITH " "${target_folders[@]}"
        fi
    done
    echo "TEST"
    echo "folders: " "${target_folders[@]}"
    print_line
    package_charts_inside_folders "${target_folders[@]}"


        # look last tag for dependency
        # discovering changed charts
        # echo "pack dependency"
        # if folder found - pack

    # release pack
    # update index

    # find all folders without dependency

    # look at all folder matrix : folder name > chart name > dependency name
    # look if `dependency` name in `chart name`
    # look last tag for dependency
    # discovering changed charts

    # create 2 matrix with dependency and without



    #get chart folders only
    #for each folder look what commit id for last release, if no release - release it
    #check if there changes, if there are changes - release it

    exit 1

}

print_line() {
    echo "============================================="
}

package_charts_inside_folders() {
    local folders=($@)
    for folder in "${folders[@]}"; do
        print_line
        echo "Looking up latest release tag for $folder"
        local chart_name
        chart_name=$(awk '/^name/{print $2}' "$charts_dir/$folder/Chart.yaml")
        local tag
        tag=$(lookup_latest_tag_of_chart "$chart_name")

        echo "Discovering changed charts since '$tag'..."
        local changed_files
        changed_files=$(git diff --find-renames --name-only "$tag" -- "$folder")
        echo $changed_files
        local depth=$(( $(tr "/" "\n" <<< "$folder" | sed '/^\(\.\)*$/d' | wc -l) + 1 ))
        local fields="1-${depth}"

        cut -d '/' -f "$fields" <<< "$changed_files" | uniq | filter_charts

    done
    exit 1


    local changed_charts=()
    readarray -t changed_charts <<< "$(lookup_changed_charts "$tag")"

    if [[ -n "${changed_charts[*]}" ]]; then
        install_chart_releaser

        rm -rf .cr-release-packages
        mkdir -p .cr-release-packages

        rm -rf .cr-index
        mkdir -p .cr-index

        for chart in "${changed_charts[@]}"; do
            if [[ -d "$chart" ]]; then
                package_chart "$chart"
            else
                echo "Chart '$chart' no longer exists in repo. Skipping it..."
            fi
        done

        release_charts
        update_index
    else
        echo "Nothing to do. No chart changes detected."
    fi

    popd > /dev/null
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            --config)
                if [[ -n "${2:-}" ]]; then
                    config="$2"
                    shift
                else
                    echo "ERROR: '--config' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -v|--version)
                if [[ -n "${2:-}" ]]; then
                    version="$2"
                    shift
                else
                    echo "ERROR: '-v|--version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -d|--charts-dir)
                if [[ -n "${2:-}" ]]; then
                    charts_dir="$2"
                    shift
                else
                    echo "ERROR: '-d|--charts-dir' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -u|--charts-repo-url)
                if [[ -n "${2:-}" ]]; then
                    charts_repo_url="$2"
                    shift
                else
                    echo "ERROR: '-u|--charts-repo-url' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -o|--owner)
                if [[ -n "${2:-}" ]]; then
                    owner="$2"
                    shift
                else
                    echo "ERROR: '--owner' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -r|--repo)
                if [[ -n "${2:-}" ]]; then
                    repo="$2"
                    shift
                else
                    echo "ERROR: '--repo' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            *)
                break
                ;;
        esac

        shift
    done

    if [[ -z "$owner" ]]; then
        echo "ERROR: '-o|--owner' is required." >&2
        show_help
        exit 1
    fi

    if [[ -z "$repo" ]]; then
        echo "ERROR: '-r|--repo' is required." >&2
        show_help
        exit 1
    fi

    if [[ -z "$charts_repo_url" ]]; then
        charts_repo_url="https://$owner.github.io/$repo"
    fi
}

install_chart_releaser() {
    if [[ ! -d "$RUNNER_TOOL_CACHE" ]]; then
        echo "Cache directory '$RUNNER_TOOL_CACHE' does not exist" >&2
        exit 1
    fi

    local arch
    arch=$(uname -m)

    local cache_dir="$RUNNER_TOOL_CACHE/ct/$version/$arch"
    if [[ ! -d "$cache_dir" ]]; then
        mkdir -p "$cache_dir"

        echo "Installing chart-releaser..."
        curl -sSLo cr.tar.gz "https://github.com/helm/chart-releaser/releases/download/$version/chart-releaser_${version#v}_linux_amd64.tar.gz"
        tar -xzf cr.tar.gz -C "$cache_dir"
        rm -f cr.tar.gz

        echo 'Adding cr directory to PATH...'
        export PATH="$cache_dir:$PATH"
    fi
}

lookup_latest_tag_of_chart() { # replace for lookup_latest_tag
    local chart_name=$1

    git fetch --tags > /dev/null 2>&1

    # first_folder=$(ls -d */ | head -n 1)Chart.yaml
    # chart_name=$(awk '/name:/{print $2}' "$first_folder" | head -n 1)

    tag=$(git describe --tags --abbrev=0 --match="$chart_name*")
    err=$(echo $?)
    if [[ $err = 0 ]]; then
        git rev-list -n 1 "$tag"
    fi
}

lookup_latest_tag() {
    git fetch --tags > /dev/null 2>&1

    if ! git describe --tags --abbrev=0 2> /dev/null; then
        git rev-list --max-parents=0 --first-parent HEAD
    fi
}

filter_charts() {
    while read -r chart; do
        [[ ! -d "$chart" ]] && continue
        local file="$chart/Chart.yaml"
        if [[ -f "$file" ]]; then
            echo "$chart"
        else
           echo "WARNING: $file is missing, assuming that '$chart' is not a Helm chart. Skipping." 1>&2
        fi
    done
}

lookup_changed_charts() {
    local commit="$1"

    local changed_files
    changed_files=$(git diff --find-renames --name-only "$commit" -- "$charts_dir")

    local depth=$(( $(tr "/" "\n" <<< "$charts_dir" | sed '/^\(\.\)*$/d' | wc -l) + 1 ))
    local fields="1-${depth}"

    cut -d '/' -f "$fields" <<< "$changed_files" | uniq | filter_charts
}

lookup_changed_chart() {
    local commit="$1"

    local changed_files
    changed_files=$(git diff --find-renames --name-only "$commit" -- "$charts_dir")

    local depth=$(( $(tr "/" "\n" <<< "$charts_dir" | sed '/^\(\.\)*$/d' | wc -l) + 1 ))
    local fields="1-${depth}"

    cut -d '/' -f "$fields" <<< "$changed_files" | uniq | filter_charts
}

package_chart() {
    local chart="$1"

    local args=("$chart" --package-path .cr-release-packages)
    if [[ -n "$config" ]]; then
        args+=(--config "$config")
    fi

    echo "Packaging chart '$chart'..."
    cr package "${args[@]}"
}

release_charts() {
    local args=(-o "$owner" -r "$repo" -c "$(git rev-parse HEAD)")
    if [[ -n "$config" ]]; then
        args+=(--config "$config")
    fi

    echo 'Releasing charts...'
    cr upload "${args[@]}"
}

update_index() {
    local args=(-o "$owner" -r "$repo" -c "$charts_repo_url" --push)
    if [[ -n "$config" ]]; then
        args+=(--config "$config")
    fi

    echo 'Updating charts repo index...'
    cr index "${args[@]}"
}

main "$@"
