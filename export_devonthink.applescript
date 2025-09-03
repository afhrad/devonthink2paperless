use AppleScript version "2.7"
use scripting additions

property exportedCount : 0
property skippedCount : 0

on run argv
	if (count of argv) is not 2 then
		my die("Usage: osascript export_min_clean.applescript \"/Pfad/zu/DB.dtBase2\" \"/Pfad/zum/Zielordner\"")
	end if
	
	set dbPath to my expandUser(item 1 of argv)
	set outRoot to my expandUser(item 2 of argv)
	
	if my pathExists(dbPath) is false then my die("DB-Pfad nicht gefunden: " & dbPath)
	do shell script "mkdir -p " & quoted form of outRoot
	
	tell application "DEVONthink 3"
		if not (running) then launch
		set dbRef to open database dbPath
		set dbName to name of dbRef
	end tell
	
	set rootDest to outRoot & "/" & my sanitizeFilename(dbName)
	do shell script "mkdir -p " & quoted form of rootDest
	
	tell application "DEVONthink 3"
		my exportGroup(root of dbRef, rootDest)
	end tell
	
	do shell script "printf '%s\\n' " & quoted form of ("Fertig: " & rootDest)
    do shell script "printf '%s\\n' " & quoted form of ("Exportierte Dateien: " & (exportedCount as string))
    do shell script "printf '%s\\n' " & quoted form of ("Übersprungen:        " & (skippedCount as string))
end run


on exportGroup(g, dest)
  tell application "DEVONthink 3"
    set nm to name of g
    set kids to children of g

    -- 1) Sonderfälle am Root: Trash/Tags komplett überspringen
    if (nm is "Papierkorb") or (nm is "Trash") or (nm is "Tags") then
      return
    end if

    -- 2) Eingang/Inbox: Inhalte flach in 'dest' schreiben (kein eigener Ordner)
    if (nm is "Eingang") or (nm is "Inbox") then
      set here to dest
    else
      -- normale Gruppe: Unterordner anlegen
      set here to dest & "/" & my safeName(nm)
      do shell script "mkdir -p " & quoted form of here
    end if

    repeat with r in kids
      if (type of r) is group then
        -- Rekursiv nur für normale Gruppen (Sondergruppen werden per Name oben gefiltert)
        my exportGroup(r, here)
      else
        -- Dateien/Einträge exportieren
        my exportOne(r, here)
      end if
    end repeat
  end tell
end exportGroup


on exportOne(r, here)
  -- Versucht 3 Wege: export (String) ? export (Alias) ? ditto von 'path of r'
  try
    tell application "DEVONthink 3"
      set exportedPaths to (export r to here) -- Ziel als POSIX-String
    end tell
    set p to my firstPath(exportedPaths)
    if p is not missing value then
      set exportedCount to exportedCount + 1
      my writeRecordJSON(r, p)
      return
    end if
  on error errMsg number errNum
    do shell script "printf '%s\\n' " & quoted form of ("SKIP(export-string): " & (name of r) & " ? " & errMsg)
  end try

  try
    set hereAlias to (POSIX file here) as alias
    tell application "DEVONthink 3"
      set exportedPaths to (export r to hereAlias) -- Ziel als Alias
    end tell
    set p to my firstPath(exportedPaths)
    if p is not missing value then
      set exportedCount to exportedCount + 1
      my writeRecordJSON(r, p)
      return
    end if
  on error errMsg2 number errNum2
    do shell script "printf '%s\\n' " & quoted form of ("SKIP(export-alias): " & (name of r) & " ? " & errMsg2)
  end try

  -- Fallback: Kopieren vom Quellpfad
  try
    tell application "DEVONthink 3"
      set srcPath to path of r -- POSIX-Pfad, falls vorhanden
      set recName to name of r
    end tell
    if srcPath is not missing value then
      -- Ziel-Dateiname: möglichst Originaldateiname mit Erweiterung
      set baseName to do shell script "/usr/bin/basename " & quoted form of srcPath
      if baseName is "" then set baseName to my safeName(recName)
      set destPath to here & "/" & baseName
      do shell script "/usr/bin/ditto " & quoted form of srcPath & " " & quoted form of destPath
      set exportedCount to exportedCount + 1
      my writeRecordJSON(r, destPath)
      return
    else
      set skippedCount to skippedCount + 1
      log quoted form of ("SKIP(no-src-path): " & recName)
    end if
  on error errMsg3 number errNum3
    set skippedCount to skippedCount + 1
    tell application "DEVONthink 3" to set nm to name of r
    log quoted form of ("SKIP(ditto): " & nm & " ? " & errMsg3)
  end try
end exportOne

on firstPath(x)
  if x is missing value then return missing value
  if class of x is list then
    if (count of x) > 0 then return item 1 of x
    return missing value
  else
    return x
  end if
end firstPath


on safeName(s)
  set s to my replaceText(s, "/", "-")
  set s to my replaceText(s, ":", "-")
  if s is "" then set s to "Unbenannt"
  return s
end safeName

on writeRecordJSON(r, exportedPath)
  -- Alle relevanten Metadaten robust einsammeln
  tell application "DEVONthink 3"
    set recName to ""
    try
      set recName to name of r
    on error
      set recName to ""
    end try

    set recUUID to ""
    try
      set recUUID to uuid of r
    on error
      set recUUID to ""
    end try

    set cDate to missing value
    try
      set cDate to creation date of r
    on error
      set cDate to missing value
    end try

    set mDate to missing value
    try
      set mDate to modification date of r
    on error
      set mDate to missing value
    end try

    set tagsList to {}
    try
      set tagsList to tags of r
    on error
      set tagsList to {}
    end try

    set urlVal to ""
    try
      set urlVal to URL of r
    on error
      set urlVal to ""
    end try

    set refURLVal to ""
    try
      set refURLVal to reference URL of r
    on error
      set refURLVal to ""
    end try

    set kindVal to ""
    try
      set kindVal to kind of r
    on error
      set kindVal to ""
    end try

    set typeVal to ""
    try
      set typeVal to (class of r) as string
    on error
      set typeVal to ""
    end try

    set sizeVal to missing value
    try
      set sizeVal to size of r
    on error
      set sizeVal to missing value
    end try

    set commentVal to ""
    try
      set commentVal to comment of r
    on error
      set commentVal to ""
    end try

    set ratingVal to missing value
    try
      set ratingVal to rating of r
    on error
      set ratingVal to missing value
    end try

    set flaggedVal to missing value
    try
      set flaggedVal to flagged of r
    on error
      set flaggedVal to missing value
    end try

    set unreadVal to missing value
    try
      set unreadVal to unread of r
    on error
      set unreadVal to missing value
    end try

    set lockedVal to missing value
    try
      set lockedVal to locked of r
    on error
      set lockedVal to missing value
    end try

    set indexedVal to missing value
    try
      set indexedVal to indexed of r
    on error
      set indexedVal to missing value
    end try

    set labelVal to missing value
    try
      set labelVal to label of r
    on error
      set labelVal to missing value
    end try

    set pathVal to ""
    try
      set pathVal to path of r
    on error
      set pathVal to ""
    end try

    set locationVal to ""
    try
      set locationVal to location of r
    on error
      set locationVal to ""
    end try

    -- optionale / typabhängige Felder
    set wordCountVal to missing value
    try
      set wordCountVal to word count of r
    on error
      set wordCountVal to missing value
    end try

    set pageCountVal to missing value
    try
      set pageCountVal to page count of r
    on error
      set pageCountVal to missing value
    end try

    set authorVal to ""
    try
      set authorVal to author of r
    on error
      set authorVal to ""
    end try

    set titleVal to ""
    try
      set titleVal to title of r
    on error
      set titleVal to ""
    end try
  end tell

  -- Dateierweiterung aus dem exportierten Pfad ableiten (ohne Python)
  set ext to ""
  try
    set baseName to do shell script "/usr/bin/basename " & quoted form of exportedPath
    set otid to AppleScript's text item delimiters
    set AppleScript's text item delimiters to "."
    set tis to text items of baseName
    set AppleScript's text item delimiters to otid
    if (count of tis) > 1 then set ext to item -1 of tis
  end try

  -- JSON-Teile nur mit vorhandenen Werten füllen
  set parts to {}
  set parts to my addKVText(parts, "name", recName)
  set parts to my addKVText(parts, "uuid", recUUID)

  if cDate is not missing value then set parts to my addKVText(parts, "created", my iso8601(cDate))
  if mDate is not missing value then set parts to my addKVText(parts, "modified", my iso8601(mDate))

  set parts to my addKVArray(parts, "tags", tagsList)

  set parts to my addKVText(parts, "url", urlVal)
  set parts to my addKVText(parts, "referenceURL", refURLVal)
  set parts to my addKVText(parts, "kind", kindVal)
  set parts to my addKVText(parts, "type", typeVal)
  set parts to my addKVText(parts, "comment", commentVal)
  set parts to my addKVText(parts, "path", pathVal)
  set parts to my addKVText(parts, "location", locationVal)
  set parts to my addKVText(parts, "author", authorVal)
  set parts to my addKVText(parts, "title", titleVal)
  set parts to my addKVText(parts, "filenameExtension", ext)

  set parts to my addKVNum(parts, "size", sizeVal)
  set parts to my addKVNum(parts, "rating", ratingVal)
  set parts to my addKVNum(parts, "label", labelVal)
  set parts to my addKVNum(parts, "wordCount", wordCountVal)
  set parts to my addKVNum(parts, "pageCount", pageCountVal)
  set parts to my addKVBool(parts, "flagged", flaggedVal)
  set parts to my addKVBool(parts, "unread", unreadVal)
  set parts to my addKVBool(parts, "locked", lockedVal)
  set parts to my addKVBool(parts, "indexed", indexedVal)

  -- JSON schreiben
  set payload to "{" & my join(parts, ",") & "}"
  set jsonPath to exportedPath & ".metadata.json"
  my writeText(payload, jsonPath)
end writeRecordJSON

-- ===== Utilities (nur ASCII, keine Sondertokens) =====

on writeText(t, posixPath)
	do shell script "mkdir -p " & quoted form of (do shell script "dirname " & quoted form of posixPath)
	set cmd to "printf %s " & my shQuote(t) & " > " & quoted form of posixPath
	do shell script cmd
end writeText

on shQuote(s)
	-- sichere Single-Quote-Quoting für die Shell: ' ? '\''  (end quote, escaped quote, reopen)
	set s to my replaceText(s, "'", "'\\''")
	return "'" & s & "'"
end shQuote

on jsonArray(L)
	if (class of L is not list) then set L to {L}
	set parts to {}
	repeat with x in L
		set end of parts to "\"" & my jsonEscape(x as string) & "\""
	end repeat
	return "[" & my join(parts, ",") & "]"
end jsonArray

on jsonEscape(s)
	set s to my replaceText(s, "\\", "\\\\")
	set s to my replaceText(s, "\"", "\\\"")
	set s to my replaceText(s, return, "\\r")
	set s to my replaceText(s, linefeed, "\\n")
	set s to my replaceText(s, tab, "\\t")
	return s
end jsonEscape

on sanitizeFilename(s)
	set s to my replaceText(s, "/", "-")
	set s to my replaceText(s, ":", "-")
	if s is "" then set s to "Unbenannt"
	return s
end sanitizeFilename

on iso8601(d)
	set y to year of d as integer
	set mo to my twoDigits(my monthIndex(month of d))
	set da to my twoDigits(day of d as integer)
	set hh to my twoDigits(hours of d as integer)
	set mm to my twoDigits(minutes of d as integer)
	set ss to my twoDigits(seconds of d as integer)
	return (y as string) & "-" & mo & "-" & da & "T" & hh & ":" & mm & ":" & ss
end iso8601

on monthIndex(m)
	set L to {January, February, March, April, May, June, July, August, September, October, November, December}
	repeat with i from 1 to 12
		if item i of L is m then return i
	end repeat
	return 1
end monthIndex

on twoDigits(n)
	if n < 10 then return "0" & n
	return n as string
end twoDigits

on join(L, sep)
	if L is {} then return ""
	set acc to item 1 of L
	repeat with i from 2 to (count of L)
		set acc to acc & sep & item i of L
	end repeat
	return acc
end join

on replaceText(t, f, r)
	set {otid, text item delimiters} to {text item delimiters, f}
	set parts to text items of t
	set text item delimiters to r
	set t to parts as text
	set text item delimiters to otid
	return t
end replaceText

on expandUser(p)
	if p starts with "~/" then
		set home to do shell script "printf %s \"$HOME\""
		return home & text 2 thru -1 of p
	else
		return p
	end if
end expandUser

on pathExists(p)
	set rc to do shell script "test -e " & quoted form of p & " && echo 1 || echo 0"
	return rc is "1"
end pathExists

on die(msg)
	do shell script "printf '%s\\n' " & quoted form of msg
	error number 1
end die

on addKVText(L, k, v)
  if v is missing value then return L
  if v is "" then return L
  set end of L to "\"" & k & "\":\"" & my jsonEscape(v as string) & "\""
  return L
end addKVText

on addKVNum(L, k, v)
  if v is missing value then return L
  try
    set _ to v as number
    set end of L to "\"" & k & "\":" & (v as string)
  on error
    return L
  end try
  return L
end addKVNum

on addKVBool(L, k, v)
  if v is missing value then return L
  try
    if v then
      set end of L to "\"" & k & "\":true"
    else
      set end of L to "\"" & k & "\":false"
    end if
  on error
    return L
  end try
  return L
end addKVBool

on addKVArray(L, k, arr)
  try
    if (class of arr is not list) then set arr to {arr}
  end try
  if arr is {} then return L
  set parts to {}
  repeat with x in arr
    set end of parts to "\"" & my jsonEscape(x as string) & "\""
  end repeat
  set end of L to "\"" & k & "\":[" & my join(parts, ",") & "]"
  return L
end addKVArray
