#!/bin/bash

######################################################
#
# Download and deploy the "calcentral.knob" (see WAR_URL).
#
######################################################

JUNCTION_DEPLOY_PROPERTIES="${HOME}/.calcentral_config/junction-deploy.properties"

function getDeployProperty {
  # Default properties file
  PROPERTIES="./config/settings/junction-deploy.properties"

  if [ "$(grep -c "^${1}=" "${JUNCTION_DEPLOY_PROPERTIES}")" -ne '0' ]; then
    # If value found in custom properties file then use it.
    PROPERTIES="${JUNCTION_DEPLOY_PROPERTIES}"
  fi

  grep "^${1}=" "${PROPERTIES}" | cut -d'=' -f2
}

GET_KNOB_FILE_FROM_AWS_S3=false

if [ -f "${JUNCTION_DEPLOY_PROPERTIES}" ]; then
  GET_KNOB_FILE_FROM_AWS_S3=$(getProperty 'feature.flag.s3.deploy' | awk '{print tolower($0)}')
  GET_KNOB_FILE_FROM_AWS_S3="$(echo -e "${GET_KNOB_FILE_FROM_AWS_S3}" | tr -d '[:space:]')"
fi

HOST=$(uname -n)
if [[ "${HOST}" = *calcentral* ]]; then
  APP_MODE="calcentral"
else
  APP_MODE="junction"
fi

MAX_ASSET_AGE_IN_DAYS=${MAX_ASSET_AGE_IN_DAYS:="45"}
DOC_ROOT="/var/www/html/${APP_MODE}"

LOG=$(date +"${PWD}/log/update-build_%Y-%m-%d.log")
LOGIT="tee -a ${LOG}"

cd $( dirname "${BASH_SOURCE[0]}" )/..

# Enable rvm and use the correct Ruby version and gem set.
[[ -s "${HOME}/.rvm/scripts/rvm" ]] && . "${HOME}/.rvm/scripts/rvm"
source .rvmrc

# Update source tree (from which these scripts run)
./script/update-source.sh

echo | ${LOGIT}
echo "------------------------------------------" | ${LOGIT}
echo "$(date): Stopping CalCentral..." | ${LOGIT}

./script/stop-torquebox.sh

rm -rf deploy
mkdir deploy
cd deploy

echo | ${LOGIT}
echo "------------------------------------------" | ${LOGIT}
echo "$(date): Fetching new calcentral.knob from ${WAR_URL}..." | ${LOGIT}

if [ "${GET_KNOB_FILE_FROM_AWS_S3}" == 'true' ]; then

  # Get calcentral.knob file from S3 bucket in AWS
  aws_access_key_id=$(getProperty 'aws.access.key')
  aws_secret_access_key=$(getProperty 'aws.secret.access')
  aws_s3_bucket=$(getProperty 'aws.s3.bucket')
  junction_knob_id=$(getProperty 'junction.knob.id')
  junction_git_branch=$(getProperty 'junction.git.branch')

  if [[ -z "${aws_access_key_id}" || -z "${aws_secret_access_key}" || -z "${aws_s3_bucket}" || -z "${junction_git_branch}" ]]; then
    echo "[ERROR] One or more required settings not found in ${JUNCTION_DEPLOY_PROPERTIES}."
    exit 1
  fi

  # Download from S3
  export AWS_ACCESS_KEY_ID="${aws_access_key_id}"
  export AWS_SECRET_ACCESS_KEY="${aws_secret_access_key}"

  s3_path="s3://${aws_s3_bucket}/${junction_git_branch}/${junction_knob_id}/calcentral.knob"

  echo "Begin download: ${s3_path}"; echo

  aws s3 cp "${s3_path}" .

else
  # Get calcentral.knob file from Bamboo (deprecated deployment strategy)
  WAR_URL=${WAR_URL:="https://bamboo.media.berkeley.edu/bamboo/browse/MYB-MVPWAR/latest/artifact/JOB1/warfile/calcentral.knob"}
  curl -k -s ${WAR_URL} > calcentral.knob

fi

echo "Unzipping knob..." | ${LOGIT}

jar xf calcentral.knob

if [ ! -d "versions" ]; then
  echo "$(date): ERROR: Missing or malformed calcentral.knob file!" | ${LOGIT}
  exit 1
fi
echo "Last commit in calcentral.knob:" | ${LOGIT}
cat versions/git.txt | ${LOGIT}

# Fix permissions on files that need to be executable
chmod u+x ./script/*
chmod u+x ./vendor/bundle/jruby/2.3.0/bin/*
find ./vendor/bundle -name standalone.sh | xargs chmod u+x

echo | ${LOGIT}
echo "------------------------------------------" | ${LOGIT}
echo "$(date): Deploying new CalCentral knob..." | ${LOGIT}

bundle exec torquebox deploy calcentral.knob --env=production | ${LOGIT}

echo "Copying assets into ${DOC_ROOT}" | ${LOGIT}
cp -Rvf public/assets ${DOC_ROOT} | ${LOGIT}

echo "Deleting old assets from ${DOC_ROOT}/assets" | ${LOGIT}
find ${DOC_ROOT}/assets -type f -mtime +${MAX_ASSET_AGE_IN_DAYS} -delete | ${LOGIT}

echo "Copying bCourses static files into ${DOC_ROOT}" | ${LOGIT}
cp -Rvf public/canvas ${DOC_ROOT} | ${LOGIT}

echo "Copying OAuth static files into ${DOC_ROOT}" | ${LOGIT}
cp -Rvf public/oauth ${DOC_ROOT} | ${LOGIT}

exit 0
