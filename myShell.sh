#!/bin/bash

display_help() {
    echo "Syntax: $0 [filters] [directory path]"
    echo "Searches for files with a specific extension in the given directory AND its subdirectories."
    echo "Generates a report with file details and groups the files by owner."
    echo "Sorts the files by the total size occupied by each owner."
    echo "Saves the report in a file named 'file_analysis.txt'."
    echo ""
    echo "Filters:"
    echo "-h, --help         Display this help section."
    echo "-e, --extension   Specify the file extension to search for."
    echo "-s, --size         Filter files by size. Available operators: +, -, =. Example: +1048576K, -1024M, =1G."
    echo "-p, --permissions  Filter files by permissions. Example: 755, 644."
    echo "-m, --modified     Filter files by last modified timestamp. Example: +10 (older than 10 days), -3 (newer than 3 days)."
    echo "-r, --report       Generate a summary report instead of the file analysis report with total file count, total size, and largest file."
}

validate_directory_path() {     #Check if the path is provided, exists, and is a directory 
    local path="$1"

    if [ -z "$path" ] || [ ! -d "$path" ]; then
        echo "ERROR: '$path' is not a valid directory."
        echo "Please enter a valid directory path."
        exit 1
    fi
}



generateReport() {      #Generates File Analysis Report
    local path="$1"
    local report_file="file_analysis.txt"
    local size_filter=$(get_size_filter "$size")
    local perm_filter=$(get_permissions_filter "$permissions")
    local modified_filter=$(get_modified_filter "$modified")

    echo "Generating file analysis report..."
    echo "Directory: $path"
    echo ""

    find "$path" -type f -name "*.$extension" $size_filter $perm_filter $modified_filter -exec ls -l {} + | \
    #find command used to extract the files with the specified extension, filter using size, permissions, and last modified timestamp in the given directory and its subdirectories

    awk 'BEGIN {
        print "File Analysis Report"
        print "_______________________________________"
        print "Owner\tSize\tLast Modified\t\tFile Path"
    }
    {
        printf "%s\t%s\t%s\t%s\n", $3, $5, $6 " " $7 " " $8, $9
        owner[$3]++
        size[$3] += $5
        count[$3]++
    }
    END {
        print "_______________________________________"
        for (o in owner) {
            print "Owner: " o
            print "Total Size: " size[o] " bytes"
            print "Number of Files: " count[o]
            print "_______________________________________"
        }
    }' > "$report_file"

    echo "File analysis report generated successfully. Saved as '$report_file'."
}

get_size_filter() {     #Helper function (size) for the 'find' command used in generateReport()
    local size="$1"
    local size_filter=""

    if [ -n "$size" ]; then
        local operator="${size:0:1}"    #extract only the operator
        local size_value="${size:1}"    #extract size value

        case "$operator" in
            +) size_filter="-size +${size_value}c" ;;
            -) size_filter="-size -${size_value}c" ;;
            =) size_filter="-size ${size_value}c" ;;
            *) echo "ERROR: Invalid size operator. Supported operators are +, -, and =." >&2; exit 1 ;;
        esac

        echo "$size_filter"
    fi
}

get_permissions_filter() {      #Helper function (permissions) for the 'find' command used in generateReport()
    local permissions="$1"
    local permissions_filter=""

    if [ -n "$permissions" ]; then
        permissions_filter="-perm $permissions"
        echo "$permissions_filter"
    else
        echo ""
    fi
}

get_modified_filter() {     #Helper function (timestamp) for the 'find' command used in generateReport()
    local modified="$1"
    local modified_filter=""

    if [ -n "$modified" ]; then
        local operator="${modified:0:1}"    #extract only the operator
        local days_value="${modified:1}"    #extract time value in days

        # Construct the modified timestamp filter for the 'find' command
        case "$operator" in
            +) modified_filter="-mtime +${days_value}" ;;
            -) modified_filter="-mtime -${days_value}" ;;
            *) echo "ERROR: Invalid modified operator. Supported operators are + and -." >&2; exit 1 ;;
        esac

        echo "$modified_filter"
    else
        echo ""
    fi
}

generateSummary() {     #Generates summary report
    local path="$1"

    echo "Generating summary report..."
    echo "Directory: $path"
    echo ""

    local file_count=$(find "$path" -type f | wc -l)
    local total_size=$(find "$path" -type f -exec stat -f "%z" {} + | awk '{sum += $1} END {print sum}')
    local largest_file=$(find "$path" -type f -exec du -h {} + | sort -rh | head -n 1)

    echo "Summary Report"
    echo "_______________________________________"
    echo "Total File Count: $file_count"
    echo "Total Size: $total_size bytes"
    echo "Largest File: $largest_file"
    echo "_______________________________________"
}

# Main script execution starts here

# Display help if no arguments are provided
if [ $# -eq 0 ]; then
    display_help
    exit 0
fi

# Process command-line arguments
extension=""
size=""
permissions=""
modified=""
summary_report=false

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            display_help
            exit 0
            ;;
        -e|--extension)
            extension="$2"
            shift
            ;;
        -s|--size)
            size="$2"
            shift
            ;;
        -p|--permissions)
            permissions="$2"
            shift
            ;;
        -m|--modified)
            modified="$2"
            shift
            ;;
        -r|--report)
            summary_report=true
            ;;
        *)
            validate_directory_path "$1"
            if [ "$summary_report" = true ]; then
                generateSummary "$1"
            else
                generateReport "$1"
            fi
            exit 0
            ;;
    esac
    shift
done