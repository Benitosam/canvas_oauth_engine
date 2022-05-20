module CanvasOauth
  # We get into a weird case with the CDN with canvas where the Content-Type for a CSV comes back as text/csv, but there
  # is no associated charset with it. HTTParty will default to treating it as binary (aka ASCII-8BIT) data which causes
  # issues downstream when the data gets combined with local application data. In cases where we can reasonably know
  # it'll be a UTF-8 compatible file (i.e any csv file from canvas) we'll force an encoding of UTF-8 if ruby thinks its
  # ASCII-8BIT
  class DefaultUTF8Parser < HTTParty::Parser
    def parse
      body.force_encoding("UTF-8") if body&.encoding == Encoding::ASCII_8BIT
      super
    end
  end
end
