'use strict'

const archiver = require('archiver')
const async = require('async')

const response = require('../response')
const config = require('../config')
const models = require('../models')
const logger = require('../logger')
const { generateAvatar } = require('../letter-avatars')

exports.getMe = async (req, res) => {
  if (!req.isAuthenticated()) {
    return res.status(401).send({
      status: 'forbidden'
    })
  }

  const user = await models.User.findOne({
    where: {
      id: req.user.id
    }
  })

  if (!user) {
    return response.errorNotFound(req, res)
  }
  const profile = models.User.getProfile(user)

  res.send({
    status: 'ok',
    id: req.user.id,
    name: profile.name,
    photo: profile.photo
  })
}

exports.deleteUser = async (req, res) => {//modhere
  if (!req.isAuthenticated()) {
    return response.errorForbidden(req, res)
  }

  const user = await models.User.findOne({
    where: {
      id: req.user.id
    }
  })

  if (!user) {
    return response.errorNotFound(req, res)
  }

  if (user.deleteToken !== req.params.token) {
    return response.errorForbidden(req, res)
  }

  await user.destroy()
  // #############################################
  // Delet user notes as well
  // #############################################
   try {
    const deleteNote = await models.Note.destroy({
      where: {
        ownerId: req.user.id
      }
    });
   } catch (error){
    console.log(`Error deleting note:`,error)
   }
  // #############################################
  // Delete USER uploads
  // #############################################
   const uploadDir = '/home/hackmd/app/public/uploads'
   try {
      fs.accessSync(uploadDir, fs.constants.F_OK)
   } catch (e) {
      console.log(`Error: `,e)
   }
   let files
   try {
      files = fs.readdirSync(uploadDir)
   } catch (e) {
      console.log(`Error reading directory:`,e)
   }
   const filesToDelete = files.filter(file => {
      return file.includes(`_${req.user.id}_`,filesToDelete)
   })
   filesToDelete.forEach(file => {
      const filePath = path.join(uploadDir, file)
      try {
          fs.unlinkSync(filePath)
          console.log(`Deleted file: `, filePath)
      } catch (e) {
          console.log(`Error Deleting file: `,e)
      }
   });
  return res.redirect(config.serverURL + '/')
}

exports.exportMyData = (req, res) => {
  if (!req.isAuthenticated()) {
    return response.errorForbidden(req, res)
  }

  const archive = archiver('zip', {
    zlib: { level: 3 } // Sets the compression level.
  })

  res.setHeader('Content-Type', 'application/zip')
  res.attachment('archive.zip')
  archive.pipe(res)
  archive.on('error', function (err) {
    logger.error('export user data failed: ' + err)
    return response.errorInternalError(req, res)
  })

  models.User.findOne({
    where: {
      id: req.user.id
    }
  }).then(function (user) {
    models.Note.findAll({
      where: {
        ownerId: user.id
      }
    }).then(function (notes) {
      const filenames = {}
      async.each(notes, function (note, callback) {
        const basename = note.title.replace(/\//g, '-') // Prevent subdirectories
        let filename
        let suffix = 0
        do {
          if (suffix === 0) {
            filename = basename + '.md'
          } else {
            filename = basename + '-' + suffix + '.md'
          }
          suffix++
        } while (filenames[filename])
        filenames[filename] = true

        logger.debug('Write: ' + filename)
        archive.append(Buffer.from(note.content), { name: filename, date: note.lastchangeAt })
        callback(null, null)
      }, function (err) {
        if (err) {
          return response.errorInternalError(req, res)
        }

        archive.finalize()
      })
    })
  }).catch(function (err) {
    logger.error('export user data failed: ' + err)
    return response.errorInternalError(req, res)
  })
}

exports.getMyAvatar = (req, res) => {
  res.setHeader('Content-Type', 'image/svg+xml')
  res.setHeader('Cache-Control', 'public, max-age=86400')
  res.send(generateAvatar(req.params.username))
}
