if [ ${PRIMARY} = "true" ] && [ ${TRAVIS_BRANCH} = "master" ] && [ ${TRAVIS_PULL_REQUEST} = "false" ]
then
    make docs
    git config --global user.email "lodo1995@users.noreply.github.com"
    git config --global user.name "travis-ci"
    git clone --quiet --branch=gh-pages https://${GH_TOKEN}@github.com/lodo1995/experimental.xml.git gh-pages
    cd gh-pages
    git rm -rf .
    cp -r ../docs/* .
    git add -A
    git commit -m "Documentation updated by Travis CI (build $TRAVIS_BUILD_NUMBER)"
    git push https://${GH_TOKEN}@github.com/lodo1995/experimental.xml.git gh-pages
    cd ..
    
    bash <(curl -s https://codecov.io/bash)
fi