import os, base64, math, strutils

if paramCount() < 2:
    echo "Version 0.1 by crackman2"
    echo "Usage:   batchman [input file] [output file] [options]"
    echo "Example: batchman file.exe     file.bat      mp"
    echo " Generates batch script that drops the input file"
    echo " Options:"
    echo ""
    echo "output file"
    echo "  -p        Append \"pause\""
    echo "  -r        Run file after dropping"
    echo "  -i        Enables progress indicator in batch file (WARNING, bloat)"
    echo "  -m        Enables message [Loading. Please wait] in batch file"
    echo "  -t        Set input filename as command prompt title"
    echo "  -x        Delete batch script after execution"
    echo "  -d        Delete dropped file after execution (requires -p)"
    echo ""
    echo "generation"
    echo "  -v        Disables printing the progress while generating"
    
    quit(0)


if not fileExists(paramStr(1)):
    echo "Error: File not found [", paramStr(1), "]"
    quit(0)


var
    opt_pause = false     #p
    opt_execute = false   #r
    opt_indicator = false #i
    opt_progress = true   #v
    opt_messages = false  #m
    opt_title = false     #t
    opt_suicide = false   #x
    opt_delete = false    #d


if paramCount() > 2:
    var opt:string = paramStr(3)
    opt = opt.toLower()

    for i in opt:
        case i:
        of '-':
            continue
        of 'p':
            opt_pause = true  
        of 'r':
            opt_execute = true
        of 'i':
            opt_indicator = true
        of 'v':
            opt_progress = false
        of 'm':
            opt_messages = true
        of 't':
            opt_title = true
        of 'x':
            opt_suicide = true
        of 'd':
            opt_delete = true
        else:
            echo "Error: Invalid option [",i,"]. Run batchman without arguments for help"
            quit(0)




var
    max_chunk_length = 8096
    input_name = paramStr(1)
    output_name = paramStr(2)
    input_data = readFile(input_name).encode()
    input_data_len = len(input_data)
    result_data = ""

    chunk_byte_index = 0       
    chunk_byte_index_label = 0 # Label current datachunk in final batchfile



result_data &= "@echo off\n"
if opt_title: result_data &= "title " & input_name & "\n"
if opt_messages: result_data &= "echo Loading. Please wait\n"
if opt_indicator: result_data &= "set x=(set /p =.)\n"


var
    current_progress = 0
    last_progess = 0

## Assign base64 data in chunks using set command
while true:


    ## Check if the next chunk is going beyond EOF
    if(chunk_byte_index+max_chunk_length < input_data_len):
        var cache = ""
        for i in chunk_byte_index..<chunk_byte_index+max_chunk_length:
            cache &= input_data[i]
        result_data &= "set d" & $chunk_byte_index_label & "=" & cache & "\n"


    else: ## Write last chunk
        var cache = ""
        for i in chunk_byte_index..<input_data_len:
            cache &= input_data[i]
        result_data &= "set d" & $chunk_byte_index_label & "=" &
                cache & "\n"
        break
    
    if opt_indicator: result_data &= "<nul %x%\n"
    
    inc(chunk_byte_index_label)
    chunk_byte_index+=max_chunk_length

    if opt_progress:
        current_progress = int(math.ceil((chunk_byte_index / input_data_len)*100))
        if current_progress != last_progess:
            last_progess = current_progress
            stdout.write("\rProgress: " & $current_progress & "%")
if opt_progress: stdout.write("\rProgress 100%")

if opt_indicator: result_data &= "echo.\n"

result_data &= "set en=%CD%\\enf.txt\n"


## Use <nul (set /p =%datachunk%) to avoid whitespace when piping output to encoded_file.txt
for i in 0..chunk_byte_index_label:
    result_data &= "<nul (set /p =%d" & $i & "%) >> %en%\n"


result_data &= "certutil -decode %en% \"%CD%\\" & input_name & "\" > nul \n"
result_data &= "del %en%\n"
if opt_execute: result_data &= "\"" & input_name & "\"\n" ## Execute the resulting file
if opt_pause  : result_data &= "pause\n"
if opt_delete : result_data &= "del \"" & input_name & "\"\n"
if opt_suicide: result_data &= "del %0\n"

echo "\nSaving to file..."
writeFile(output_name, result_data)
echo "File written [", output_name, "] Size [", len(result_data), " B | ", len(result_data) div 1000, " KB | ", len(result_data) div 1000000, " MB]"