import multer from "multer";
import { v2 as cloudinary } from "cloudinary";
import { config } from "dotenv";
import { CloudinaryStorage } from "multer-storage-cloudinary";

config();

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

export const cloudinaryUploadMiddleware = (options = {}) => {
  const defaultOptions = {
    folder: "uploads",
    allowed_formats: ["jpg", "jpeg", "png", "gif"],
    maxFiles: 5,
  };

  const uploadOptions = { ...defaultOptions, ...options };

  const storage = new CloudinaryStorage({
    cloudinary,
    params: {
      folder: uploadOptions.folder,
      allowed_formats: uploadOptions.allowed_formats,
    },
  });

  const upload = multer({
    storage: storage,
    limits: {
      fileSize: 5 * 1024 * 1024,
    },
  });

  return (req, res, next) => {
    // Determine if single or multiple upload
    const uploadType = uploadOptions.multiple
      ? upload.array("images", uploadOptions.maxFiles)
      : upload.single("nft");

    // Execute upload middleware
    uploadType(req, res, (err) => {
      if (err instanceof multer.MulterError) {
        return res.status(400).json({
          error: "Upload error",
          message: err.message,
        });
      } else if (err) {
        return res.status(500).json({
          error: "Server error",
          message: err.message,
        });
      }

      console.log({
        url: req.file.path,
        publicId: req.file.filename,
      });

      if (req.file) {
        req.cloudinaryUpload = {
          url: req.file.path,
          publicId: req.file.filename,
        };
      }

      if (req.files) {
        req.cloudinaryUploads = req.files.map((file) => ({
          url: file.path,
          publicId: file.filename,
        }));
      }

      next();
    });
  };
};

export const cloudinaryDeleteMiddleware = () => {
  return async (req, res, next) => {
    try {
      const { imageId } = req.body;
      if (!imageId) {
        return res.status(400).json({ error: "No image ID provided" });
      }

      const result = await cloudinary.uploader.destroy(imageId);
      req.cloudinaryDeletion = result;
      next();
    } catch (error) {
      res.status(500).json({
        error: "Deletion failed",
        details: error.message,
      });
    }
  };
};
