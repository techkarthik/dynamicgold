import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { initMasterSchema } from "./config/schema.js";
import {
  sendOtpController,
  verifyOtpController,
  registerController,
  loginController,
  verifyEmailController,
} from "./controllers/authController.js";
import {
  getProfileController,
  updateProfileController,
  getTenantDbStatusController,
  getTenantDbTablesController,
  optimizeTenantDbController,
  getTenantDbOverviewController,
  executeTenantQueryController,
  testTenantDbHealthController,
  reinstallTenantDbController,
} from "./controllers/tenantController.js";
import {
  getCompaniesController,
  createCompanyController,
  updateCompanyController,
  deleteCompanyController,
} from "./controllers/companyController.js";
import {
  getBranchesController,
  createBranchController,
  updateBranchController,
  deleteBranchController,
} from "./controllers/branchController.js";
import {
  getUsersController,
  createUserController,
  updateUserController,
  changePasswordController,
  deleteUserController,
  recoverPasswordOtpController,
} from "./controllers/userController.js";
import {
  getEmployeesController,
  createEmployeeController,
  updateEmployeeController,
  deleteEmployeeController,
} from "./controllers/employeeController.js";
import {
  getAccountHeadsController,
  getAccountHeadOptionsController,
  createAccountHeadOptionController,
  createAccountHeadController,
  updateAccountHeadController,
  deleteAccountHeadController,
} from "./controllers/accountHeadController.js";
import {
  getTaxMasterController,
  createTaxMasterController,
  updateTaxMasterController,
  deleteTaxMasterController,
} from "./controllers/taxMasterController.js";
import {
  getMetalsController,
  createMetalController,
  updateMetalController,
  deleteMetalController,
  getPuritiesController,
  createPurityController,
  updatePurityController,
  deletePurityController,
  getCategoriesController,
  createCategoryController,
  updateCategoryController,
  deleteCategoryController,
  getProductsController,
  createProductController,
  updateProductController,
  deleteProductController,
  getSubProductsController,
  createSubProductController,
  updateSubProductController,
  deleteSubProductController,
  getStylesController,
  createStyleController,
  updateStyleController,
  deleteStyleController,
  getSizesController,
  createSizeController,
  updateSizeController,
  deleteSizeController,
  getPriceSettingsController,
  getPriceSettingDealersController,
  createPriceSettingController,
  updatePriceSettingController,
  deletePriceSettingController,
  getDiamondPriceSettingsController,
  getDiamondProductsController,
  createDiamondPriceSettingController,
  updateDiamondPriceSettingController,
  deleteDiamondPriceSettingController,
  getDesignersController,
  createDesignerController,
  updateDesignerController,
  deleteDesignerController,
} from "./controllers/inventoryMasterController.js";
import {
  getSystemControlsController,
  createSystemControlController,
  updateSystemControlController,
  deleteSystemControlController,
} from "./controllers/systemControlsController.js";
import {
  getEstimatesController,
  getBarcodeForEstimateController,
  searchAvailableSkusController,
  createEstimateController,
  updateEstimateController,
  deleteEstimateController,
  bulkDeleteEstimatesByDateController,
} from "./controllers/estimateController.js";
import {
  getLatestRatesController,
  getRatesByDateController,
  bulkUpdateRatesController,
  getRateHistoryController,
  deleteRateRecordController,
} from "./controllers/rateMasterController.js";
import {
  uploadImageController,
  getUploadAuthController,
  deleteImageController,
} from "./controllers/uploadController.js";
import {
  getPrepareSkuLotsController,
  createPrepareSkuLotController,
  updatePrepareSkuLotController,
  deletePrepareSkuLotController,
} from "./controllers/stockController.js";
import {
  getBarcodeTemplatesController,
  createBarcodeTemplateController,
  updateBarcodeTemplateController,
  deleteBarcodeTemplateController,
  setDefaultBarcodeTemplateController,
} from "./controllers/barcodeTemplateController.js";
import {
  getStockTagsController,
  getVaLookupController,
  generateTagsFromLotController,
  updateStockTagController,
  deleteStockTagController,
  markStockTagsPrintedController,
} from "./controllers/stockTaggingController.js";
import { requireAuth } from "./middleware/authMiddleware.js";

import path from "path";
import { fileURLToPath } from "url";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const webBuildPath = path.resolve(__dirname, "../../frontend/build/web");

const app = express();
const PORT = process.env.PORT || 5000;

// Enable CORS for web clients
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.use(express.json({ limit: "25mb" }));
app.use(express.urlencoded({ extended: true, limit: "25mb" }));

// Serve compiled Flutter web app
app.use(express.static(webBuildPath));

// API Health Check
app.get("/api/health", (req, res) => {
  res.json({
    status: "online",
    message: "ProGold Multi-Tenant PostgreSQL Backend API is running smoothly.",
    timestamp: new Date().toISOString(),
  });
});

// Authentication Routes
app.post("/api/auth/send-otp", sendOtpController);
app.post("/api/auth/verify-otp", verifyOtpController);
app.post("/api/auth/register", registerController);
app.post("/api/auth/verify-email", verifyEmailController);
app.post("/api/auth/login", loginController);

// Authenticated Tenant Routes
app.get("/api/tenant/profile", requireAuth, getProfileController);
app.put("/api/tenant/profile", requireAuth, updateProfileController);
app.get("/api/tenant/db/status", requireAuth, getTenantDbStatusController);
app.get("/api/tenant/db/tables", requireAuth, getTenantDbTablesController);
app.post("/api/tenant/db/optimize", requireAuth, optimizeTenantDbController);
app.get("/api/tenant/db/overview", requireAuth, getTenantDbOverviewController);
app.get("/api/tenant/db/health", requireAuth, testTenantDbHealthController);
app.post("/api/tenant/db/query", requireAuth, executeTenantQueryController);
app.post("/api/tenant/db/reinstall", requireAuth, reinstallTenantDbController);

// Tenant Company Master CRUD Routes
app.get("/api/tenant/companies", requireAuth, getCompaniesController);
app.post("/api/tenant/companies", requireAuth, createCompanyController);
app.put("/api/tenant/companies/:id", requireAuth, updateCompanyController);
app.delete("/api/tenant/companies/:id", requireAuth, deleteCompanyController);

// Tenant Branch Master CRUD Routes
app.get("/api/tenant/branches", requireAuth, getBranchesController);
app.post("/api/tenant/branches", requireAuth, createBranchController);
app.put("/api/tenant/branches/:id", requireAuth, updateBranchController);
app.delete("/api/tenant/branches/:id", requireAuth, deleteBranchController);

// Tenant User Master CRUD & Password Management Routes
app.get("/api/tenant/users", requireAuth, getUsersController);
app.post("/api/tenant/users", requireAuth, createUserController);
app.put("/api/tenant/users/:id", requireAuth, updateUserController);
app.delete("/api/tenant/users/:id", requireAuth, deleteUserController);
app.post("/api/tenant/users/:id/change-password", requireAuth, changePasswordController);
app.post("/api/tenant/users/recover-password", requireAuth, recoverPasswordOtpController);

// Tenant Employee Master CRUD Routes
app.get("/api/tenant/employees", requireAuth, getEmployeesController);
app.post("/api/tenant/employees", requireAuth, createEmployeeController);
app.put("/api/tenant/employees/:id", requireAuth, updateEmployeeController);
app.delete("/api/tenant/employees/:id", requireAuth, deleteEmployeeController);

// Tenant Account Head CRUD Routes
app.get("/api/tenant/account-heads", requireAuth, getAccountHeadsController);
app.get("/api/tenant/account-heads/options", requireAuth, getAccountHeadOptionsController);
app.post("/api/tenant/account-heads/options", requireAuth, createAccountHeadOptionController);
app.post("/api/tenant/account-heads", requireAuth, createAccountHeadController);
app.put("/api/tenant/account-heads/:id", requireAuth, updateAccountHeadController);
app.delete("/api/tenant/account-heads/:id", requireAuth, deleteAccountHeadController);

// Tenant Tax Master CRUD Routes
app.get("/api/tenant/tax-master", requireAuth, getTaxMasterController);
app.post("/api/tenant/tax-master", requireAuth, createTaxMasterController);
app.put("/api/tenant/tax-master/:id", requireAuth, updateTaxMasterController);
app.delete("/api/tenant/tax-master/:id", requireAuth, deleteTaxMasterController);

// Tenant Metals CRUD Routes
app.get("/api/tenant/metals", requireAuth, getMetalsController);
app.post("/api/tenant/metals", requireAuth, createMetalController);
app.put("/api/tenant/metals/:id", requireAuth, updateMetalController);
app.delete("/api/tenant/metals/:id", requireAuth, deleteMetalController);

// Tenant Purities CRUD Routes
app.get("/api/tenant/purities", requireAuth, getPuritiesController);
app.post("/api/tenant/purities", requireAuth, createPurityController);
app.put("/api/tenant/purities/:id", requireAuth, updatePurityController);
app.delete("/api/tenant/purities/:id", requireAuth, deletePurityController);

// Tenant Categories CRUD Routes
app.get("/api/tenant/categories", requireAuth, getCategoriesController);
app.post("/api/tenant/categories", requireAuth, createCategoryController);
app.put("/api/tenant/categories/:id", requireAuth, updateCategoryController);
app.delete("/api/tenant/categories/:id", requireAuth, deleteCategoryController);

// Tenant Products CRUD Routes (4th Master under Inventory)
app.get("/api/tenant/products", requireAuth, getProductsController);
app.post("/api/tenant/products", requireAuth, createProductController);
app.put("/api/tenant/products/:id", requireAuth, updateProductController);
app.delete("/api/tenant/products/:id", requireAuth, deleteProductController);

// Tenant Sub-Products CRUD Routes (5th Master under Inventory)
app.get("/api/tenant/subproducts", requireAuth, getSubProductsController);
app.post("/api/tenant/subproducts", requireAuth, createSubProductController);
app.put("/api/tenant/subproducts/:id", requireAuth, updateSubProductController);
app.delete("/api/tenant/subproducts/:id", requireAuth, deleteSubProductController);

// Tenant Styles CRUD Routes (6th Master under Inventory)
app.get("/api/tenant/styles", requireAuth, getStylesController);
app.post("/api/tenant/styles", requireAuth, createStyleController);
app.put("/api/tenant/styles/:id", requireAuth, updateStyleController);
app.delete("/api/tenant/styles/:id", requireAuth, deleteStyleController);

// Tenant Sizes CRUD Routes (7th Master under Inventory)
app.get("/api/tenant/sizes", requireAuth, getSizesController);
app.post("/api/tenant/sizes", requireAuth, createSizeController);
app.put("/api/tenant/sizes/:id", requireAuth, updateSizeController);
app.delete("/api/tenant/sizes/:id", requireAuth, deleteSizeController);

// Tenant Price Setting CRUD Routes (8th Master under Inventory)
app.get("/api/tenant/price-settings", requireAuth, getPriceSettingsController);
app.get("/api/tenant/price-settings/dealers", requireAuth, getPriceSettingDealersController);
app.post("/api/tenant/price-settings", requireAuth, createPriceSettingController);
app.put("/api/tenant/price-settings/:id", requireAuth, updatePriceSettingController);
app.delete("/api/tenant/price-settings/:id", requireAuth, deletePriceSettingController);

// Tenant Diamond Price Setting CRUD Routes (Master under Inventory)
app.get("/api/tenant/diamond-price-settings", requireAuth, getDiamondPriceSettingsController);
app.get("/api/tenant/diamond-price-settings/products", requireAuth, getDiamondProductsController);
app.post("/api/tenant/diamond-price-settings", requireAuth, createDiamondPriceSettingController);
app.put("/api/tenant/diamond-price-settings/:id", requireAuth, updateDiamondPriceSettingController);
app.delete("/api/tenant/diamond-price-settings/:id", requireAuth, deleteDiamondPriceSettingController);

// Tenant Designer Master CRUD Routes (Master under Inventory)
app.get("/api/tenant/designers", requireAuth, getDesignersController);
app.post("/api/tenant/designers", requireAuth, createDesignerController);
app.put("/api/tenant/designers/:id", requireAuth, updateDesignerController);
app.delete("/api/tenant/designers/:id", requireAuth, deleteDesignerController);

// Tenant Stock Prepare for SKU CRUD Routes (Stock Menu)
app.get("/api/tenant/stock/prepare-sku", requireAuth, getPrepareSkuLotsController);
app.post("/api/tenant/stock/prepare-sku", requireAuth, createPrepareSkuLotController);
app.put("/api/tenant/stock/prepare-sku/:id", requireAuth, updatePrepareSkuLotController);
app.delete("/api/tenant/stock/prepare-sku/:id", requireAuth, deletePrepareSkuLotController);

// Tenant Barcode & RFID Templates CRUD Routes
app.get("/api/tenant/barcode-templates", requireAuth, getBarcodeTemplatesController);
app.post("/api/tenant/barcode-templates", requireAuth, createBarcodeTemplateController);
app.put("/api/tenant/barcode-templates/:id", requireAuth, updateBarcodeTemplateController);
app.delete("/api/tenant/barcode-templates/:id", requireAuth, deleteBarcodeTemplateController);
app.post("/api/tenant/barcode-templates/:id/set-default", requireAuth, setDefaultBarcodeTemplateController);

// Tenant Stock Barcode & RFID Tagging Routes (Stock Menu)
app.get("/api/tenant/stock/tags", requireAuth, getStockTagsController);
app.get("/api/tenant/stock/va-lookup", requireAuth, getVaLookupController);
app.post("/api/tenant/stock/tags/generate-from-lot", requireAuth, generateTagsFromLotController);
app.put("/api/tenant/stock/tags/:id", requireAuth, updateStockTagController);
app.delete("/api/tenant/stock/tags/:id", requireAuth, deleteStockTagController);
app.post("/api/tenant/stock/tags/mark-printed", requireAuth, markStockTagsPrintedController);

// Tenant System Controls CRUD Routes (4th Menu under Settings)
app.get("/api/tenant/system-controls", requireAuth, getSystemControlsController);
app.post("/api/tenant/system-controls", requireAuth, createSystemControlController);
app.put("/api/tenant/system-controls/:id", requireAuth, updateSystemControlController);
app.delete("/api/tenant/system-controls/:id", requireAuth, deleteSystemControlController);

// Tenant Estimates / Quotation Routes (3rd Main Menu)
app.get("/api/tenant/estimates", requireAuth, getEstimatesController);
app.get("/api/tenant/estimates/search-skus", requireAuth, searchAvailableSkusController);
app.get("/api/tenant/estimates/barcode-lookup/:sku", requireAuth, getBarcodeForEstimateController);
app.get("/api/tenant/estimates/barcode-lookup", requireAuth, getBarcodeForEstimateController);
app.post("/api/tenant/estimates", requireAuth, createEstimateController);
app.put("/api/tenant/estimates/:id", requireAuth, updateEstimateController);
app.delete("/api/tenant/estimates/bulk/date-range", requireAuth, bulkDeleteEstimatesByDateController);
app.delete("/api/tenant/estimates/:id", requireAuth, deleteEstimateController);

// Tenant Daily Purity Rates & History Routes (Rate Master)
app.get("/api/tenant/rates/latest", requireAuth, getLatestRatesController);
app.get("/api/tenant/rates/by-date", requireAuth, getRatesByDateController);
app.post("/api/tenant/rates/bulk-update", requireAuth, bulkUpdateRatesController);
app.get("/api/tenant/rates/history", requireAuth, getRateHistoryController);
app.delete("/api/tenant/rates/:id", requireAuth, deleteRateRecordController);

// Tenant Media Upload & ImageKit Routes (Employees, Catalogues, Item Tags)
app.post("/api/tenant/upload/image", requireAuth, uploadImageController);
app.get("/api/tenant/upload/auth", requireAuth, getUploadAuthController);
app.delete("/api/tenant/upload/image/:fileId", requireAuth, deleteImageController);

// SPA fallback to index.html
app.get("*", (req, res, next) => {
  if (req.path.startsWith("/api/")) return next();
  res.sendFile(path.join(webBuildPath, "index.html"), (err) => {
    if (err) next();
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error("Unhandled server error:", err);
  res.status(500).json({ success: false, message: "Internal server error." });
});

// Initialize Schema and Start Server
async function startServer() {
  try {
    await initMasterSchema();
    app.listen(PORT, "0.0.0.0", () => {
      console.log(`\n======================================================`);
      console.log(` ProGold Multi-Tenant Server running on http://localhost:${PORT}`);
      console.log(" PostgreSQL master database: Connected");
      console.log(` Ready for Flutter Web & Desktop requests!`);
      console.log(`======================================================\n`);
    });
  } catch (error) {
    console.error("Failed to start server due to PostgreSQL initialization error:", error);
    process.exit(1);
  }
}

startServer();
