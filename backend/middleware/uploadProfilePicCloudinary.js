const multer = require('multer');
const path = require('path');
const cloudinary = require('../cloudinary');
const streamifier = require('streamifier');

const storage = multer.memoryStorage();
const upload = multer({
  storage,
  limits: { fileSize: 2 * 1024 * 1024 }, // 2MB máximo
  fileFilter: (req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
      return cb(new Error('Solo se permiten imágenes'));
    }
    cb(null, true);
  }
});

async function uploadToCloudinary(req, res, next) {
  if (!req.file) return next();
  try {
    const stream = cloudinary.uploader.upload_stream(
      { folder: 'profile_pics' },
      (error, result) => {
        if (error) return next(error);
        req.file.cloudinaryUrl = result.secure_url;
        next();
      }
    );
    streamifier.createReadStream(req.file.buffer).pipe(stream);
  } catch (e) {
    next(e);
  }
}

module.exports = { upload, uploadToCloudinary };
