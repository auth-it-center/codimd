'use strict'

const crypto = require('crypto')
const fs = require('fs')
const URL = require('url').URL
const path = require('path')

const config = require('../config')
const logger = require('../logger')

const MAX_IMAGE_SIZE = 5 * 1024 * 1024
/**
 * generate a random filename for uploaded image
 */
function randomFilename (userid) {
  const buf = crypto.randomBytes(16)
  return `upload_${userid}_${buf.toString('hex')}`
}

/**
 * pick a filename not exist in filesystem
 * maximum attempt 5 times
 */
function pickFilename (defaultFilename,req) {
  let retryCounter = 5
  const extname = path.extname(defaultFilename)
  const userid = req.user.id
  let filename = `${randomFilename(userid)}${extname}`
  while (retryCounter-- > 0) {
    if (fs.existsSync(path.join(config.uploadsPath, filename))) {
      filename = `${randomFilename(userid)}${extname}`
      continue
    }
    return filename
  }
  throw new Error('file exists.')
}
//modhere

exports.uploadImage = function (req,imagePath, callback) {
  if (!imagePath || typeof imagePath !== 'string') {
    callback(new Error('Image path is missing or wrong'), null)
    return
  }

  if (!callback || typeof callback !== 'function') {
    logger.error('Callback has to be a function')
    return
  }

  // modhere
  // Check image size
  let stats
  try {
    stats = fs.statSync(imagePath)
  } catch (e) {
    return callback(new Error('Failed to read the image file'), null)
  }

  // If the image is too large, reject the upload
  if (stats.size > MAX_IMAGE_SIZE) {
    return callback(new Error('Image size exceeds the 5MB limit'), null)
  }

  let filename = path.basename(imagePath)
  try {
    filename = pickFilename(path.basename(imagePath),req)
  } catch (e) {
    return callback(e, null)
  }

  try {
    fs.copyFileSync(imagePath, path.join(config.uploadsPath, filename))
  } catch (e) {
    return callback(e, null)
  }

  let url
  try {
    url = (new URL(filename, config.serverURL + '/uploads/')).href
  } catch (e) {
    url = config.serverURL + '/uploads/' + filename
  }

  callback(null, url)
}
