source ../_env/bin/activate
mkdocs build
rm -rf ../docs
cp -r site ../docs
