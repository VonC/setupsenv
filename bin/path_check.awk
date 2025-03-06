BEGIN{
  RS=";"; 
  ORS=";"; 
  found=0; 
  found_multiple=0; 
  first=1;
  path_output = "";
  # Default debug to off if not provided
  if (debug == "") debug = 0;
}
{
  # Trim leading/trailing whitespace including newlines
  gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0);

  # Debug output
  if (debug) print "DEBUG: Processing segment [" $0 "]" > "/dev/stderr";
  
  if (tolower($0) == tolower(jdk_bin_path) && found==0) {
    if (debug) print "DEBUG: Matched jdk_bin_path" > "/dev/stderr";
    if(!first) path_output = path_output ";";
    first=0;
    path_output = path_output $0;
    found=1;
  } else if (!index(tolower($0), tolower(prefix))) {
    if (debug) print "DEBUG: No prefix match, keeping" > "/dev/stderr";
    if(!first) path_output = path_output ";";
    first=0;
    path_output = path_output $0;
  } else {
    if (debug) print "DEBUG: Found other java path, skipping" > "/dev/stderr";
    found_multiple=1;
  }
}
END{
  if (debug) print "DEBUG: Final path_output=[" path_output "]" > "/dev/stderr";

  ORS="";
    # Ensure no trailing newline or semi-coma in final output
  sub(/[\r\n;]+$/, "", path_output);
  
  # Print everything on one line with no trailing newline
  printf "%s#@#%d%d", path_output, found, found_multiple;
}
