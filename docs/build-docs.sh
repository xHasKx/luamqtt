#!/bin/bash

# generate docs filtering some known errors
ldoc . 2> >(grep -v -P "protocol.lua:\d+: protocol\.packet_type: undocumented formal argument: '\[\d+\]'")

# replacing generated README.md.html link with the github readme page - https://github.com/xHasKx/luamqtt#readme
rm ./topics/README.md.html
find -type f -name '*.html' | xargs sed -i 's/\.\.\/topics\/README\.md\.html/https\:\/\/github\.com\/xHasKx\/luamqtt\#readme/g'
find -type f -name '*.html' | xargs sed -i 's/topics\/README\.md\.html/https\:\/\/github\.com\/xHasKx\/luamqtt\#readme/g'
echo "README.md link fixed"

echo "Done"

