if [ ${PRIMARY} = "true" ] && [ ${TRAVIS_BRANCH} = "master" ] && [ ${TRAVIS_PULL_REQUEST = "false"} ]
then
    make docs
    git clone --quiet --branch=gh-pages https://${GH_TOKEN}@github.com/lodo1995/experimental.xml.git gh-pages > /dev/null
    cd gh-pages
    git rm -rf .
    cp -R ../docs/* ./*
    git add .
    git push https://${GH_TOKEN}@github.com/lodo1995/experimental.xml.git gh-pages
    
    bash <(curl -s https://codecov.io/bash)
fi