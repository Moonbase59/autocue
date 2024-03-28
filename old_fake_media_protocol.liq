# fake_media_protocol.liq
# 2024-03-16 - Moonbase59

# This is only used for local testing, i.e. without AzuraCast.
# So I don’t have to change the protocol code.
# Include this BEFORE 'autocue.liq'.

# Use YOUR base media folder here.
station_media_dir = "/home/matthias/Musik"

def azuracast_media_protocol(~rlog=_,~maxtime=_,arg) =
    ["#{station_media_dir}/#{arg}"]
end

protocol.add(
    "media",
    azuracast_media_protocol,
    doc="Pull files from AzuraCast media directory.",
    syntax="media:uri"
)
