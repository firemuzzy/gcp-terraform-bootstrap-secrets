#!/bin/sh

######################################################
# CONFIG VARIABLES
######################################################

# Secrets that need to be seeded and then importeted
SECRETS=( "SECRET_1" "SECRET_2" "SECRET_3" )

# region where the state bucket is created
# and also this is set int tfvars
REGION=us-central1

# to create the tfstate bucket, combine project is and suffix
# to create bucket name for state
TF_STATE_BUCKET_SUFFIX=_tfstate

######################################################
# END  CONFIG VARIABLES
######################################################

#
# seed gcp secrete manager value with a random string if it is not there
#
on_missing_secret_value_fill_w_random() {
  local PROJECT_ID="$1"
  local SECRET_NAME="$2"
  local CREATED=1

  local RAND_VAL=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
  # Check if the secret exists in Google Cloud Secret Manager
  SECRET_EXISTS=$(gcloud secrets list --project="${PROJECT_ID}" --filter="name~${SECRET_NAME}" --format="value(NAME)" 2>/dev/null)
  if [[ ! -n "${SECRET_EXISTS}" ]]; then
    # no secret, create it
    echo " ⚠️   ${PROJECT_ID} - creating secret ${SECRET_NAME} with a random value"
    echo "${RAND_VAL}" | gcloud secrets create "${SECRET_NAME}" --data-file=-
    CREATED=0
  else
    # check for version
    # Check if the secret has at least one active version
    ACTIVE_VERSIONS=$(gcloud secrets versions list "${SECRET_NAME}" --project="${PROJECT_ID}" --filter="state='ENABLED'" --format="value(NAME)" 2>/dev/null)

    if [[ ! -n "${ACTIVE_VERSIONS}" ]]; then
      # create a new active version
      echo " ⚠️  ${PROJECT_ID} - secret ${SECRET_NAME} has no active version, creating with a random value"
      echo "${RAND_VAL}" | gcloud secrets versions add "${SECRET_NAME}" --data-file=-
      CREATED=0
    else
      echo " ✅  ${PROJECT_ID} - has secret ${SECRET_NAME} with an active version"
    fi

  fi

  return $CREATED
}


######################################################
# PARSE COMMAND lINKE ARGS
######################################################

show_help() { echo "Usage: $0 [-p <string>]" 1>&2; exit 1; }

# A POSIX variable
# Reset in case getopts has been used previously in the shell.
OPTIND=1        
while getopts "h?p:" opt; do
  case "$opt" in
    h|\?)
      show_help
      exit 0
      ;;
    p)  
      ARG_GCP_PROJECT_ID=$OPTARG
      ;;
  esac
done

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

if [ -z ${ARG_GCP_PROJECT_ID} ];
then
    echo "Please provide a GCP Project ID under -p options"
    show_help
    exit 1
fi

# the project to configure, loaded in from command line args
GCP_PROJECT_ID=${ARG_GCP_PROJECT_ID}

# bucket configs for storing state in GCP
TF_STATE_BUCKET_NAME=${GCP_PROJECT_ID}${TF_STATE_BUCKET_SUFFIX}
TF_STATE_BUCKET=gs://${TF_STATE_BUCKET_NAME}

######################################################

echo ""
echo "Intializing..."
echo ""
echo "     GCP project: '$GCP_PROJECT_ID'"
echo "          Region: '$REGION'"
echo " TF State bucket: '$TF_STATE_BUCKET'"
echo ""

gcloud config set project ${GCP_PROJECT_ID}
gcloud services enable storage.googleapis.com
gcloud services enable secretmanager.googleapis.com

echo ""
echo "Createing tfvars:"
if [[ -f terraform.tfvars ]]; then
  echo " ⚠️  terraform.tfvars already exists, not updating with project and region"
else
  echo "project = \"${GCP_PROJECT_ID}\"" > terraform.tfvars
  echo "region  = \"${REGION}\"" >> terraform.tfvars
  echo "  done"
fi

#
# GCP STATE SETUP
#

# create a bucket for terraform state
echo ""
if gcloud storage buckets describe "${TF_STATE_BUCKET}" >/dev/null 2>&1; then
  echo "Already have state bucket"
else
  echo "Creating state bucket:"
  gcloud storage buckets create ${TF_STATE_BUCKET} \
    --location=${REGION} \
    --public-access-prevention
fi

# enable object versioning 
# https://developer.hashicorp.com/terraform/language/settings/backends/gcs
echo ""
echo "Updating state bucket to have versioning:"
gcloud storage buckets update ${TF_STATE_BUCKET} --versioning --public-access-prevention

# initialize state file
echo ""
echo "Generating state.tf with state bucket:"

echo "# !!! IMPORTANT !!!" > state.tf
echo "# Generated by gcloud.init.sh, all changed will be smashed" >> state.tf
echo "# modify state.tf.template for changes then run ./gcloud.init.sh\n" >> state.tf
sed s/STATE_BUCKET/${TF_STATE_BUCKET_NAME}/ < state.tf.template >> state.tf

echo "  done"

#
# END of GCP STATE SETUP
#

#
# SEED SECRETS
#
echo ""
echo "Seeding secrets:"

SEEDED_SECRET=0
for SECRET in ${SECRETS[*]}
do
  on_missing_secret_value_fill_w_random ${GCP_PROJECT_ID} ${SECRET}
  if [[ $? -eq 0 ]]; then
    SEEDED_SECRET=1
  fi
done

if [[ $SEEDED_SECRET -eq 1 ]]; then
  echo ""
  echo "⚠️  UPDATE secrets with real values through Secrets Manger UI"
  echo "   missing secrets were seeded with random values"
  echo "   https://console.cloud.google.com/security/secret-manager?project=${GCP_PROJECT_ID}"
fi

echo ""
terraform init
echo ""

#
# IMPORT SEEDED SECRETS, 
# will error that it already has values if ran mulitple time
# its does not really break anything, not handling it
#
echo ""
echo "Importing secrets:"
echo ""

for SECRET in ${SECRETS[*]}
do
  terraform import "google_secret_manager_secret.my_service[\"${SECRET}\"]" ${SECRET}
done


echo "\nIntialized ${GCP_PROJECT_ID}, now use terraform"