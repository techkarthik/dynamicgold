import { uploadMedia, getAuthParams, deleteMedia } from "../services/imageKitService.js";

/**
 * Controller to upload an image to ImageKit
 * Payload: { image: string (base64), fileName?: string, folder?: string, tags?: string[] }
 */
export async function uploadImageController(req, res) {
  try {
    const { image, file, fileName, folder = "employees", tags = [] } = req.body;
    const imagePayload = image || file;

    if (!imagePayload) {
      return res.status(400).json({
        success: false,
        message: "No image provided. Please send a base64 encoded image string in the 'image' field.",
      });
    }

    const autoFileName = fileName || `media_${Date.now()}.png`;

    const result = await uploadMedia({
      fileBase64: imagePayload,
      fileName: autoFileName,
      folder: folder || "employees",
      tags: Array.isArray(tags) ? tags : ["progold", folder],
    });

    return res.status(200).json({
      success: true,
      message: "Image uploaded successfully to ImageKit.",
      ...result,
    });
  } catch (error) {
    console.error("uploadImageController error:", error?.message || error);
    return res.status(500).json({
      success: false,
      message: error?.message || "Failed to upload image.",
    });
  }
}

/**
 * Controller to generate client-side upload authentication parameters
 */
export async function getUploadAuthController(req, res) {
  try {
    const authParams = getAuthParams();
    return res.status(200).json({
      success: true,
      ...authParams,
    });
  } catch (error) {
    console.error("getUploadAuthController error:", error?.message || error);
    return res.status(500).json({
      success: false,
      message: error?.message || "Failed to generate ImageKit auth parameters.",
    });
  }
}

/**
 * Controller to delete a file from ImageKit by fileId
 */
export async function deleteImageController(req, res) {
  try {
    const { fileId } = req.params;
    if (!fileId) {
      return res.status(400).json({ success: false, message: "fileId is required." });
    }
    const result = await deleteMedia(fileId);
    return res.status(result.success ? 200 : 400).json(result);
  } catch (error) {
    return res.status(500).json({ success: false, message: error?.message || "Delete failed." });
  }
}
