#!/bin/bash

# Function to display usage instructions
usage() {
  echo "Usage: clouduploader /path/to/file.txt [bucket-name] [target-directory]"
  exit 1
}

# Check if the file path is provided
if [ -z "$1" ]; then
  echo "Error: File path is required."
  usage
fi

FILE_PATH=$1
BUCKET_NAME=$2
TARGET_DIR=$3

# Check if the file exists
if [ ! -f "$FILE_PATH" ]; then
  echo "Error: File $FILE_PATH does not exist."
  exit 1
fi

# Check if the bucket name is provided
if [ -z "$BUCKET_NAME" ]; then
  echo "Error: Bucket name is required."
  usage
fi

# Optional: Default target directory if not provided
: ${TARGET_DIR:=""}

# Install pv if not installed
if ! command -v pv &> /dev/null; then
    echo "pv is not installed. Installing pv..."
    sudo apt-get update && sudo apt-get install -y pv
fi

# Check if the bucket exists
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Bucket $BUCKET_NAME does not exist. Creating bucket..."
  aws s3api create-bucket --bucket "$BUCKET_NAME" --region $(aws configure get region)
  
  if [ $? -ne 0 ]; then
    echo "Error: Failed to create bucket $BUCKET_NAME."
    exit 1
  fi
fi

# Determine S3 path based on whether target directory is provided
if [ -z "$TARGET_DIR" ]; then
  S3_PATH="s3://$BUCKET_NAME/$(basename "$FILE_PATH")"
else
  S3_PATH="s3://$BUCKET_NAME/$TARGET_DIR/$(basename "$FILE_PATH")"
fi

# Upload the file to S3 with a progress bar
pv "$FILE_PATH" | aws s3 cp - "$S3_PATH"

# Check if the upload was successful
if [ $? -eq 0 ]; then
  echo "File uploaded successfully to $S3_PATH"

  # Generate a pre-signed URL
  PRESIGNED_URL=$(aws s3 presign "$S3_PATH")
  
  if [ $? -eq 0 ]; then
    echo "Pre-signed URL: $PRESIGNED_URL"
  else
    echo "Error: Failed to generate pre-signed URL."
  fi
else
  echo "Error: Failed to upload the file."
  exit 1
fi
