# AutoDJ Next Song Script
def autodj_next_song() =
    response = azuracast_api_call(
        "nextsong",
        ""
    )
    if (response == "") or (response == "false") then
        null()
    else
        r = request.create(response)
        if request.resolve(r) then
            r
        else
            null()
       end
    end
end
