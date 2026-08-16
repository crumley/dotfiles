function ts --description "Unix timestamp to localtime"
    echo $argv | perl -nE 'say scalar localtime $_'
end
