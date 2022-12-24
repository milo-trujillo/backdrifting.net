#!/usr/bin/env bash

# This script isn't part of the website code, but should be run before
# committing anything to the repo so we don't accidentally post login creds
DIR=$(dirname "$SCRIPT")

sed -i -e 's/^PreviewPassword.*$/PreviewPassword = ""/' $DIR/backdrifting.rb
sed -i -e 's/^ShareablePreviewPassword.*$/ShareablePreviewPassword = ""/' $DIR/backdrifting.rb
sed -i -e 's/^AnalyticsPassword.*$/AnalyticsPassword = ""/' $DIR/backdrifting.rb
sed -i -e 's/^SiteName.*$/SiteName = ""/' $DIR/backdrifting.rb
sed -i -e 's/^SiteURL.*$/SiteURL = ""/' $DIR/backdrifting.rb
sed -i -e 's/^SiteDomains.*$/SiteDomains = ["example.com", "www.example.com"]/' $DIR/backdrifting.rb
sed -i -e 's/^TwitterHandle.*$/TwitterHandle = "@foo"/' $DIR/backdrifting.rb
sed -i -e 's/^Author.*$/Author = ""/' $DIR/backdrifting.rb
sed -i -e 's/^Description.*$/Description = "Digital Haven"/' $DIR/backdrifting.rb
sed -i -e 's/^AnalyticsEnabled.*$/AnalyticsEnabled = false/' $DIR/backdrifting.rb
find "${DIR}" -name "*-e" -exec rm {} \;
