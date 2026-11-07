import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { initMasterSchema } from "../backend/src/config/schema.js";
import { masterDb } from "../backend/src/config/postgres.js";
import {
  sendOtpController,
  verifyOtpController,
  registerController,
  loginController,
  verifyEmailController,
} from "../backend/src/controllers/authController.js";
import {
  getProfileController,
  updateProfileController,
  getTenantDbOverviewController,
  executeTenantQueryController,
  testTenantDbHealthController,
  reinstallTenantDbController,
  getTenantDbStatusController,
  getTenantDbTablesController,
  optimizeTenantDbController,
} from "../backend/src/controllers/tenantController.js";
import {
  getCompaniesController,
  createCompanyController,
  updateCompanyController,
  deleteCompanyController,
} from "../backend/src/controllers/companyController.js";
import {
  getBranchesController,
  createBranchController,
  updateBranchController,
  deleteBranchController,
} from "../backend/src/controllers/branchController.js";
import {
  getUsersController,
  createUserController,
  updateUserController,
  changePasswordController,
  deleteUserController,
  recoverPasswordOtpController,
} from "../backend/src/controllers/userController.js";
import {
  getEmployeesController,
  createEmployeeController,
  updateEmployeeController,
  deleteEmployeeController,
} from "../backend/src/controllers/employeeController.js";
import {
  getAccountHeadsController,
  getAccountHeadOptionsController,
  createAccountHeadOptionController,
  createAccountHeadController,
  updateAccountHeadController,
  deleteAccountHeadController,
} from "../backend/src/controllers/accountHeadController.js";
import {
  getTaxMasterController,
  createTaxMasterController,
  updateTaxMasterController,
  deleteTaxMasterController,
} from "../backend/src/controllers/taxMasterController.js";
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
} from "../backend/src/controllers/inventoryMasterController.js";
import {
  getSystemControlsController,
  createSystemControlController,
  updateSystemControlController,
  deleteSystemControlController,
} from "../backend/src/controllers/systemControlsController.js";
import {
  getEstimatesController,
  getBarcodeForEstimateController,
  searchAvailableSkusController,
  createEstimateController,
  updateEstimateController,
  deleteEstimateController,
  bulkDeleteEstimatesByDateController,
} from "../backend/src/controllers/estimateController.js";
import {
  getLatestRatesController,
  getRatesByDateController,
  bulkUpdateRatesController,
  getRateHistoryController,
  deleteRateRecordController,
} from "../backend/src/controllers/rateMasterController.js";
import {
  uploadImageController,
  getUploadAuthController,
  deleteImageController,
} from "../backend/src/controllers/uploadController.js";
import {
  getPrepareSkuLotsController,
  createPrepareSkuLotController,
  updatePrepareSkuLotController,
  deletePrepareSkuLotController,
} from "../backend/src/controllers/stockController.js";
import {
  getBarcodeTemplatesController,
  createBarcodeTemplateController,
  updateBarcodeTemplateController,
  deleteBarcodeTemplateController,
  setDefaultBarcodeTemplateController,
} from "../backend/src/controllers/barcodeTemplateController.js";
import {
  getStockTagsController,
  getVaLookupController,
  generateTagsFromLotController,
  updateStockTagController,
  deleteStockTagController,
  markStockTagsPrintedController,
} from "../backend/src/controllers/stockTaggingController.js";
import { requireAuth } from "../backend/src/middleware/authMiddleware.js";

dotenv.config();

const app = express();

// Enable CORS for all web clients & preflight
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "Accept", "Origin", "X-Requested-With"],
    credentials: true,
  })
);

app.options("*", cors());
app.use(express.json({ limit: "25mb" }));
app.use(express.urlencoded({ extended: true, limit: "25mb" }));

// Lazy-initialize Master DB Schema
let schemaInitialized = false;
let schemaPromise = null;

async function ensureSchema() {
  if (!schemaInitialized) {
    if (!schemaPromise) {
      schemaPromise = initMasterSchema()
        .then(() => {
          schemaInitialized = true;
        })
        .catch((err) => {
          schemaPromise = null;
          throw err;
        });
    }
    await schemaPromise;
  }
}

// Router containing all API endpoints
const router = express.Router();

// Middleware to ensure schema is initialized before handling route
router.use(async (req, res, next) => {
  if (req.path !== "/health" && req.path !== "/api/health") {
    try {
      await ensureSchema();
    } catch (error) {
      return next(error);
    }
  }
  next();
});

// Comprehensive Diagnostic Health Check Endpoint
router.get("/health", async (req, res) => {
  let dbStatus = "unknown";
  let dbError = null;
  let dbLatencyMs = null;

  try {
    const start = Date.now();
    await masterDb.execute("SELECT 1 AS ping;");
    dbLatencyMs = Date.now() - start;
    dbStatus = "connected";
  } catch (err) {
    dbStatus = "connection_failed";
    dbError = err?.message || String(err);
  }

  const isHealthy = dbStatus === "connected";

  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? "online" : "degraded",
    message: isHealthy
      ? "ProGold Multi-Tenant PostgreSQL Backend API is running smoothly on Vercel."
      : `ProGold API error: ${dbError}`,
    diagnostics: {
      database: {
        status: dbStatus,
        latencyMs: dbLatencyMs,
        error: dbError,
      },
      smtp: {
        configured: !!(process.env.SMTP_USER && process.env.SMTP_PASS),
        host: process.env.SMTP_HOST || "smtp.gmail.com",
        userConfigured: !!process.env.SMTP_USER,
      },
      environment: process.env.NODE_ENV || "production",
      timestamp: new Date().toISOString(),
    },
  });
});

// Authentication Routes
router.post("/auth/send-otp", sendOtpController);
router.post("/auth/verify-otp", verifyOtpController);
router.post("/auth/register", registerController);
router.post("/auth/verify-email", verifyEmailController);
router.post("/auth/login", loginController);

// Authenticated Tenant Routes
router.get("/tenant/profile", requireAuth, getProfileController);
router.put("/tenant/profile", requireAuth, updateProfileController);
router.get("/tenant/db/overview", requireAuth, getTenantDbOverviewController);
router.get("/tenant/db/health", requireAuth, testTenantDbHealthController);
router.post("/tenant/db/query", requireAuth, executeTenantQueryController);
router.post("/tenant/db/reinstall", requireAuth, reinstallTenantDbController);
router.get("/tenant/db/status", requireAuth, getTenantDbStatusController);
router.get("/tenant/db/tables", requireAuth, getTenantDbTablesController);
router.post("/tenant/db/optimize", requireAuth, optimizeTenantDbController);

// Tenant Company Master CRUD Routes
router.get("/tenant/companies", requireAuth, getCompaniesController);
router.post("/tenant/companies", requireAuth, createCompanyController);
router.put("/tenant/companies/:id", requireAuth, updateCompanyController);
router.delete("/tenant/companies/:id", requireAuth, deleteCompanyController);

// Tenant Branch Master CRUD Routes
router.get("/tenant/branches", requireAuth, getBranchesController);
router.post("/tenant/branches", requireAuth, createBranchController);
router.put("/tenant/branches/:id", requireAuth, updateBranchController);
router.delete("/tenant/branches/:id", requireAuth, deleteBranchController);

// Tenant User Master CRUD & Password Management Routes
router.get("/tenant/users", requireAuth, getUsersController);
router.post("/tenant/users", requireAuth, createUserController);
router.put("/tenant/users/:id", requireAuth, updateUserController);
router.delete("/tenant/users/:id", requireAuth, deleteUserController);
router.post("/tenant/users/:id/change-password", requireAuth, changePasswordController);
router.post("/tenant/users/recover-password", requireAuth, recoverPasswordOtpController);

// Tenant Employee Master CRUD Routes
router.get("/tenant/employees", requireAuth, getEmployeesController);
router.post("/tenant/employees", requireAuth, createEmployeeController);
router.put("/tenant/employees/:id", requireAuth, updateEmployeeController);
router.delete("/tenant/employees/:id", requireAuth, deleteEmployeeController);

// Tenant Account Head CRUD Routes
router.get("/tenant/account-heads", requireAuth, getAccountHeadsController);
router.get("/tenant/account-heads/options", requireAuth, getAccountHeadOptionsController);
router.post("/tenant/account-heads/options", requireAuth, createAccountHeadOptionController);
router.post("/tenant/account-heads", requireAuth, createAccountHeadController);
router.put("/tenant/account-heads/:id", requireAuth, updateAccountHeadController);
router.delete("/tenant/account-heads/:id", requireAuth, deleteAccountHeadController);

// Tenant Tax Master CRUD Routes
router.get("/tenant/tax-master", requireAuth, getTaxMasterController);
router.post("/tenant/tax-master", requireAuth, createTaxMasterController);
router.put("/tenant/tax-master/:id", requireAuth, updateTaxMasterController);
router.delete("/tenant/tax-master/:id", requireAuth, deleteTaxMasterController);

// Tenant Metals CRUD Routes
router.get("/tenant/metals", requireAuth, getMetalsController);
router.post("/tenant/metals", requireAuth, createMetalController);
router.put("/tenant/metals/:id", requireAuth, updateMetalController);
router.delete("/tenant/metals/:id", requireAuth, deleteMetalController);

// Tenant Purities CRUD Routes
router.get("/tenant/purities", requireAuth, getPuritiesController);
router.post("/tenant/purities", requireAuth, createPurityController);
router.put("/tenant/purities/:id", requireAuth, updatePurityController);
router.delete("/tenant/purities/:id", requireAuth, deletePurityController);

// Tenant Categories CRUD Routes
router.get("/tenant/categories", requireAuth, getCategoriesController);
router.post("/tenant/categories", requireAuth, createCategoryController);
router.put("/tenant/categories/:id", requireAuth, updateCategoryController);
router.delete("/tenant/categories/:id", requireAuth, deleteCategoryController);

// Tenant Products CRUD Routes (4th Master under Inventory)
router.get("/tenant/products", requireAuth, getProductsController);
router.post("/tenant/products", requireAuth, createProductController);
router.put("/tenant/products/:id", requireAuth, updateProductController);
router.delete("/tenant/products/:id", requireAuth, deleteProductController);

// Tenant Sub-Products CRUD Routes (5th Master under Inventory)
router.get("/tenant/subproducts", requireAuth, getSubProductsController);
router.post("/tenant/subproducts", requireAuth, createSubProductController);
router.put("/tenant/subproducts/:id", requireAuth, updateSubProductController);
router.delete("/tenant/subproducts/:id", requireAuth, deleteSubProductController);

// Tenant Styles CRUD Routes (6th Master under Inventory)
router.get("/tenant/styles", requireAuth, getStylesController);
router.post("/tenant/styles", requireAuth, createStyleController);
router.put("/tenant/styles/:id", requireAuth, updateStyleController);
router.delete("/tenant/styles/:id", requireAuth, deleteStyleController);

// Tenant Sizes CRUD Routes (7th Master under Inventory)
router.get("/tenant/sizes", requireAuth, getSizesController);
router.post("/tenant/sizes", requireAuth, createSizeController);
router.put("/tenant/sizes/:id", requireAuth, updateSizeController);
router.delete("/tenant/sizes/:id", requireAuth, deleteSizeController);

// Tenant Price Setting CRUD Routes (8th Master under Inventory)
router.get("/tenant/price-settings", requireAuth, getPriceSettingsController);
router.get("/tenant/price-settings/dealers", requireAuth, getPriceSettingDealersController);
router.post("/tenant/price-settings", requireAuth, createPriceSettingController);
router.put("/tenant/price-settings/:id", requireAuth, updatePriceSettingController);
router.delete("/tenant/price-settings/:id", requireAuth, deletePriceSettingController);

// Tenant Diamond Price Setting CRUD Routes (Master under Inventory)
router.get("/tenant/diamond-price-settings", requireAuth, getDiamondPriceSettingsController);
router.get("/tenant/diamond-price-settings/products", requireAuth, getDiamondProductsController);
router.post("/tenant/diamond-price-settings", requireAuth, createDiamondPriceSettingController);
router.put("/tenant/diamond-price-settings/:id", requireAuth, updateDiamondPriceSettingController);
router.delete("/tenant/diamond-price-settings/:id", requireAuth, deleteDiamondPriceSettingController);

// Tenant Designer Master CRUD Routes (Master under Inventory)
router.get("/tenant/designers", requireAuth, getDesignersController);
router.post("/tenant/designers", requireAuth, createDesignerController);
router.put("/tenant/designers/:id", requireAuth, updateDesignerController);
router.delete("/tenant/designers/:id", requireAuth, deleteDesignerController);

// Tenant Stock Prepare for SKU CRUD Routes (Stock Menu)
router.get("/tenant/stock/prepare-sku", requireAuth, getPrepareSkuLotsController);
router.post("/tenant/stock/prepare-sku", requireAuth, createPrepareSkuLotController);
router.put("/tenant/stock/prepare-sku/:id", requireAuth, updatePrepareSkuLotController);
router.delete("/tenant/stock/prepare-sku/:id", requireAuth, deletePrepareSkuLotController);

// Tenant Barcode & RFID Templates CRUD Routes
router.get("/tenant/barcode-templates", requireAuth, getBarcodeTemplatesController);
router.post("/tenant/barcode-templates", requireAuth, createBarcodeTemplateController);
router.put("/tenant/barcode-templates/:id", requireAuth, updateBarcodeTemplateController);
router.delete("/tenant/barcode-templates/:id", requireAuth, deleteBarcodeTemplateController);
router.post("/tenant/barcode-templates/:id/set-default", requireAuth, setDefaultBarcodeTemplateController);

// Tenant Stock Barcode & RFID Tagging Routes (Stock Menu)
router.get("/tenant/stock/tags", requireAuth, getStockTagsController);
router.get("/tenant/stock/va-lookup", requireAuth, getVaLookupController);
router.post("/tenant/stock/tags/generate-from-lot", requireAuth, generateTagsFromLotController);
router.put("/tenant/stock/tags/:id", requireAuth, updateStockTagController);
router.delete("/tenant/stock/tags/:id", requireAuth, deleteStockTagController);
router.post("/tenant/stock/tags/mark-printed", requireAuth, markStockTagsPrintedController);

// Tenant System Controls CRUD Routes (4th Menu under Settings)
router.get("/tenant/system-controls", requireAuth, getSystemControlsController);
router.post("/tenant/system-controls", requireAuth, createSystemControlController);
router.put("/tenant/system-controls/:id", requireAuth, updateSystemControlController);
router.delete("/tenant/system-controls/:id", requireAuth, deleteSystemControlController);

// Tenant Estimates / Quotation Routes (3rd Main Menu)
router.get("/tenant/estimates", requireAuth, getEstimatesController);
router.get("/tenant/estimates/search-skus", requireAuth, searchAvailableSkusController);
router.get("/tenant/estimates/barcode-lookup/:sku", requireAuth, getBarcodeForEstimateController);
router.get("/tenant/estimates/barcode-lookup", requireAuth, getBarcodeForEstimateController);
router.post("/tenant/estimates", requireAuth, createEstimateController);
router.put("/tenant/estimates/:id", requireAuth, updateEstimateController);
router.delete("/tenant/estimates/bulk/date-range", requireAuth, bulkDeleteEstimatesByDateController);
router.delete("/tenant/estimates/:id", requireAuth, deleteEstimateController);

// Tenant Daily Purity Rates & History Routes (Rate Master)
router.get("/tenant/rates/latest", requireAuth, getLatestRatesController);
router.get("/tenant/rates/by-date", requireAuth, getRatesByDateController);
router.post("/tenant/rates/bulk-update", requireAuth, bulkUpdateRatesController);
router.get("/tenant/rates/history", requireAuth, getRateHistoryController);
router.delete("/tenant/rates/:id", requireAuth, deleteRateRecordController);

// Tenant Media Upload & ImageKit Routes (Employees, Catalogues, Item Tags)
router.post("/tenant/upload/image", requireAuth, uploadImageController);
router.get("/tenant/upload/auth", requireAuth, getUploadAuthController);
router.delete("/tenant/upload/image/:fileId", requireAuth, deleteImageController);

// Mount router on both '/api' and '/' to ensure all rewrite scenarios work
app.use("/api", router);
app.use("/", router);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error("Unhandled server error:", err);
  res.status(500).json({
    success: false,
    message: err?.message || "Internal server error.",
    error: err?.message,
  });
});

export default app;
