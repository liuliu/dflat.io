cp -r ../../dflat/docs/reference/* docs/reference/
mkdocs build
rm -rf ../docs
cp -r site ../docs
