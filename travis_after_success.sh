if [ ${PRIMARY} = "true" ] && [ ${TRAVIS_BRANCH} = "master" ] && [ ${TRAVIS_PULL_REQUEST} = "false" ]
then
    make docs
    git clone --quiet --branch=gh-pages https://${GH_TOKEN}@github.com/lodo1995/experimental.xml.git gh-pages
    cd gh-pages
    git rm -rf .
    cp -r ../docs/* .
    git add .
    git commit -m "Documentation updated by Travis CI (build $TRAVIS_BUILD_NUMBER)"
    git push https://${GH_TOKEN}@github.com/lodo1995/experimental.xml.git gh-pages
    
    bash <(curl -s https://codecov.io/bash)
fi