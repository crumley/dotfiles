function upall --description "Upgrade all the things"
    if command -q brew
        brew upgrade
    end

    if functions -q fisher
        fisher update
    end

    if command -q mise
        mise upgrade
    end
end
