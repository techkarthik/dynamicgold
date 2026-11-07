import ImageKit from "imagekit";
import dotenv from "dotenv";

dotenv.config();

const DEFAULT_PUBLIC_KEY = "public_wdA0prnlWg1DqcSK/1GqoekvMVY=";
const DEFAULT_PRIVATE_KEY = "private_2KiTlbWJF902bm6z0JFNfiSjh7o=";
const DEFAULT_URL_ENDPOINT = "https://ik.imagekit.io/19agqroel/task";

/**
 * ImageKit instance initialized with environment variables (with fallback)
 */
export const imageKit = new ImageKit({
  publicKey: process.env.IMAGEKIT_PUBLIC_KEY || DEFAULT_PUBLIC_KEY,
  privateKey: process.env.IMAGEKIT_PRIVATE_KEY || DEFAULT_PRIVATE_KEY,
  urlEndpoint: process.env.IMAGEKIT_URL_ENDPOINT || DEFAULT_URL_ENDPOINT,
});

/**
 * Uploads a base64 encoded image or binary buffer to ImageKit.
 * Organized into specific folders (e.g. employees, catalogues, itemtags).
 * 
 * @param {Object} options
 * @param {string} options.fileBase64 - Base64 string (with or without data URI prefix)
 * @param {string} options.fileName - Target file name (e.g., "emp_1001_1725528000.jpg")
 * @param {string} [options.folder='employees'] - Category folder name (e.g. 'employees', 'catalogues', 'itemtags')
 * @param {string[]} [options.tags=[]] - Optional tags
 * @returns {Promise<{success: boolean, url: string, fileId: string, name: string, thumbnailUrl?: string, raw?: any}>}
 */
export async function uploadMedia({
  fileBase64,
  fileName,
  folder = "employees",
  tags = ["progold"],
}) {
  if (!fileBase64) {
    throw new Error("Missing image payload for upload.");
  }

  // Sanitize fileName
  const cleanFileName = (fileName || `upload_${Date.now()}.png`).replace(/[^a-zA-Z0-9._-]/g, "_");

  // Determine standard folder structure: /task/{folder}
  const targetFolder = folder.startsWith("/task")
    ? folder
    : `/task/${folder.replace(/^\/+/, "")}`;

  try {
    const uploadResponse = await imageKit.upload({
      file: fileBase64,
      fileName: cleanFileName,
      folder: targetFolder,
      tags: Array.isArray(tags) ? tags : [tags],
      useUniqueFileName: true,
    });

    return {
      success: true,
      url: uploadResponse.url,
      fileId: uploadResponse.fileId,
      name: uploadResponse.name,
      thumbnailUrl: uploadResponse.thumbnailUrl || uploadResponse.url,
      size: uploadResponse.size,
      filePath: uploadResponse.filePath,
    };
  } catch (error) {
    console.error("ImageKit uploadMedia failed:", error?.message || error);
    throw new Error(error?.message || "Failed to upload image to ImageKit.");
  }
}

/**
 * Deletes a file from ImageKit by fileId
 * @param {string} fileId
 */
export async function deleteMedia(fileId) {
  if (!fileId) return { success: false, message: "Missing fileId" };
  try {
    await imageKit.deleteFile(fileId);
    return { success: true };
  } catch (error) {
    console.error(`ImageKit deleteMedia failed for fileId ${fileId}:`, error?.message || error);
    return { success: false, message: error?.message || "Failed to delete file" };
  }
}

/**
 * Returns authentication parameters for direct client-side upload if needed
 */
export function getAuthParams() {
  return imageKit.getAuthenticationParameters();
}
