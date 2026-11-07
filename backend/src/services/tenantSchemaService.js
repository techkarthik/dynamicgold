import { createTenantClient } from "../config/postgres.js";
import { getTenantDatabaseOverview as getPostgresTenantDatabaseOverview } from "./postgresService.js";

export async function syncTenantDatabaseSchema(schemaName) {
  if (!schemaName) {
    throw new Error("Tenant PostgreSQL schema name is required.");
  }

  const startTime = Date.now();
  const client = createTenantClient(schemaName);

  try {
    // 1. Batch create all core ERP database tables in a single operation
    const createTablesSql = `
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version TEXT NOT NULL,
        migration_name TEXT NOT NULL,
        applied_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS organization_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_name TEXT DEFAULT 'ProGold Enterprise',
        tagline TEXT DEFAULT 'Fine Gold & Bullion Jewelers',
        phone TEXT DEFAULT '',
        email TEXT DEFAULT '',
        address TEXT DEFAULT '',
        city TEXT DEFAULT '',
        state TEXT DEFAULT '',
        pincode TEXT DEFAULT '',
        gstin TEXT DEFAULT '',
        pan_number TEXT DEFAULT '',
        currency_symbol TEXT DEFAULT '₹',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS company (
        companyid TEXT PRIMARY KEY NOT NULL,
        companyname TEXT NOT NULL,
        gstno TEXT DEFAULT '',
        mobilenumber TEXT DEFAULT '',
        address TEXT DEFAULT '',
        city TEXT DEFAULT '',
        state TEXT DEFAULT '',
        state_id INTEGER DEFAULT 0,
        country TEXT DEFAULT 'India',
        country_id INTEGER DEFAULT 1,
        accountname TEXT DEFAULT '',
        branchid TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS branches (
        branchid TEXT PRIMARY KEY NOT NULL,
        branchname TEXT NOT NULL,
        companyid TEXT NOT NULL,
        accountname TEXT DEFAULT '',
        state TEXT DEFAULT '',
        state_id INTEGER DEFAULT 0,
        country TEXT DEFAULT 'India',
        country_id INTEGER DEFAULT 1,
        address TEXT DEFAULT '',
        mobile TEXT DEFAULT '',
        email TEXT DEFAULT '',
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS users (
        userid TEXT PRIMARY KEY NOT NULL,
        username TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        email TEXT DEFAULT '',
        branchid TEXT DEFAULT '',
        is_active INTEGER DEFAULT 1,
        centlogin TEXT DEFAULT 'NO',
        profile_image TEXT DEFAULT '',
        allowed_menus TEXT DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS employees (
        empid INTEGER PRIMARY KEY AUTOINCREMENT,
        empname TEXT NOT NULL,
        branchid TEXT NOT NULL,
        dateofjoin TEXT DEFAULT '',
        active INTEGER DEFAULT 1,
        bloodgroup TEXT DEFAULT '',
        mobile TEXT DEFAULT '',
        email TEXT DEFAULT '',
        address TEXT DEFAULT '',
        image TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS gold_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purity_name TEXT NOT NULL,
        purity_karat INTEGER NOT NULL,
        purity_percent REAL NOT NULL,
        buy_rate REAL NOT NULL,
        sell_rate REAL NOT NULL,
        silver_rate REAL DEFAULT 0,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS metals (
        metalid TEXT PRIMARY KEY NOT NULL,
        metalname TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS purities (
        purityid INTEGER PRIMARY KEY AUTOINCREMENT,
        metalid TEXT NOT NULL,
        purityname TEXT NOT NULL,
        purityshortname TEXT NOT NULL,
        purity REAL NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (metalid) REFERENCES metals(metalid)
      );

      CREATE TABLE IF NOT EXISTS daily_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ratedate TEXT NOT NULL,
        purityid INTEGER NOT NULL,
        metalid TEXT NOT NULL,
        purityname TEXT NOT NULL,
        purity REAL NOT NULL,
        rate REAL NOT NULL,
        buy_rate REAL DEFAULT 0.0,
        sell_rate REAL DEFAULT 0.0,
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (purityid) REFERENCES purities(purityid)
      );

      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        metalid TEXT NOT NULL,
        purityid INTEGER,
        catcode TEXT UNIQUE NOT NULL,
        catname TEXT NOT NULL,
        categorytype TEXT NOT NULL,
        sgst_per REAL DEFAULT 0.0,
        cgst_per REAL DEFAULT 0.0,
        igst_per REAL DEFAULT 0.0,
        sales_accode TEXT DEFAULT '',
        purchase_accode TEXT DEFAULT '',
        sgst_accode TEXT DEFAULT '',
        cgst_accode TEXT DEFAULT '',
        igst_accode TEXT DEFAULT '',
        salesacname TEXT DEFAULT '',
        purchaseacname TEXT DEFAULT '',
        sgstacname TEXT DEFAULT '',
        cgstacname TEXT DEFAULT '',
        igstacname TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (metalid) REFERENCES metals(metalid),
        FOREIGN KEY (purityid) REFERENCES purities(purityid)
      );

      CREATE TABLE IF NOT EXISTS products (
        productid INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryid INTEGER NOT NULL,
        productname TEXT NOT NULL,
        calctype TEXT NOT NULL DEFAULT 'WEIGHT',
        stocktype TEXT NOT NULL DEFAULT 'SKU',
        havestone_diamond TEXT NOT NULL DEFAULT 'NO',
        havesubproduct TEXT NOT NULL DEFAULT 'NO',
        studded TEXT NOT NULL DEFAULT 'N',
        diastone TEXT NOT NULL DEFAULT '',
        hsncode TEXT NOT NULL DEFAULT '',
        stoneunit TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (categoryid) REFERENCES categories(id)
      );

      CREATE TABLE IF NOT EXISTS subproducts (
        subproductid INTEGER PRIMARY KEY AUTOINCREMENT,
        productid INTEGER NOT NULL,
        subproductname TEXT NOT NULL,
        havestone_diamond TEXT NOT NULL DEFAULT 'NO',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (productid) REFERENCES products(productid),
        UNIQUE (productid, subproductname)
      );

      CREATE TABLE IF NOT EXISTS styles (
        styleid INTEGER PRIMARY KEY AUTOINCREMENT,
        productid INTEGER NOT NULL,
        stylename TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (productid) REFERENCES products(productid),
        UNIQUE (productid, stylename)
      );

      CREATE TABLE IF NOT EXISTS sizes (
        sizeid INTEGER PRIMARY KEY AUTOINCREMENT,
        productid INTEGER NOT NULL,
        sizename TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (productid) REFERENCES products(productid),
        UNIQUE (productid, sizename)
      );

      CREATE TABLE IF NOT EXISTS pricesetting (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productid INTEGER NOT NULL,
        subproductid INTEGER DEFAULT NULL,
        accode TEXT NOT NULL,
        weight_from REAL NOT NULL DEFAULT 0.0,
        weight_to REAL NOT NULL DEFAULT 0.0,
        va_percent REAL NOT NULL DEFAULT 0.0,
        wastage REAL NOT NULL DEFAULT 0.0,
        mc_per_gram REAL NOT NULL DEFAULT 0.0,
        m_charge REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (productid) REFERENCES products(productid),
        FOREIGN KEY (subproductid) REFERENCES subproducts(subproductid)
      );

      CREATE TABLE IF NOT EXISTS system_controls (
        sno INTEGER PRIMARY KEY AUTOINCREMENT,
        ctlid TEXT NOT NULL,
        ctlname TEXT NOT NULL,
        ctlvalue TEXT NOT NULL,
        module TEXT NOT NULL,
        branch_id TEXT NOT NULL DEFAULT 'ALL',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS inventory_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        change_type TEXT NOT NULL,
        change_amount REAL NOT NULL,
        reason TEXT DEFAULT '',
        reference_id TEXT DEFAULT '',
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT DEFAULT '',
        phone TEXT NOT NULL,
        address TEXT DEFAULT '',
        city TEXT DEFAULT '',
        state TEXT DEFAULT '',
        pan_number TEXT DEFAULT '',
        gstin TEXT DEFAULT '',
        opening_balance REAL DEFAULT 0.0,
        current_balance REAL DEFAULT 0.0,
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_person TEXT DEFAULT '',
        phone TEXT NOT NULL,
        email TEXT DEFAULT '',
        address TEXT DEFAULT '',
        city TEXT DEFAULT '',
        gstin TEXT DEFAULT '',
        balance_gold REAL DEFAULT 0.0,
        balance_cash REAL DEFAULT 0.0,
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER,
        customer_name TEXT NOT NULL,
        customer_phone TEXT DEFAULT '',
        subtotal REAL DEFAULT 0.0,
        making_charges REAL DEFAULT 0.0,
        gst_percent REAL DEFAULT 3.0,
        gst_amount REAL DEFAULT 0.0,
        discount REAL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        payment_mode TEXT DEFAULT 'CASH',
        payment_status TEXT DEFAULT 'PAID',
        issue_date TEXT NOT NULL,
        due_date TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER,
        title TEXT NOT NULL,
        sku TEXT DEFAULT '',
        purity TEXT DEFAULT '22K',
        gross_weight REAL DEFAULT 0.0,
        net_weight REAL DEFAULT 0.0,
        gold_rate REAL DEFAULT 0.0,
        making_charge REAL DEFAULT 0.0,
        total_price REAL NOT NULL,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        invoice_id INTEGER,
        amount REAL NOT NULL,
        payment_mode TEXT DEFAULT 'CASH',
        reference_number TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        payment_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS estimates (
        estimate_id INTEGER PRIMARY KEY AUTOINCREMENT,
        estimate_no TEXT UNIQUE NOT NULL,
        customer_name TEXT NOT NULL,
        customer_mobile TEXT NOT NULL DEFAULT '',
        customer_address TEXT DEFAULT '',
        employee_id INTEGER,
        employee_code TEXT DEFAULT '',
        employee_name TEXT DEFAULT '',
        gross_weight REAL DEFAULT 0.0,
        net_weight REAL DEFAULT 0.0,
        total_metal_value REAL DEFAULT 0.0,
        total_making_charges REAL DEFAULT 0.0,
        total_stone_charges REAL DEFAULT 0.0,
        total_diamond_charges REAL DEFAULT 0.0,
        total_va_charges REAL DEFAULT 0.0,
        taxable_amount REAL DEFAULT 0.0,
        gst_rate REAL DEFAULT 3.0,
        tax_amount REAL DEFAULT 0.0,
        net_amount REAL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'OPEN',
        items_json TEXT NOT NULL DEFAULT '[]',
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS orders_karigar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT UNIQUE NOT NULL,
        supplier_id INTEGER,
        customer_id INTEGER,
        item_description TEXT NOT NULL,
        purity TEXT DEFAULT '22K',
        issued_gold_weight REAL DEFAULT 0.0,
        expected_delivery_date TEXT DEFAULT '',
        status TEXT DEFAULT 'IN_PROGRESS',
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS account_heads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        accode TEXT UNIQUE NOT NULL,
        groupname TEXT NOT NULL,
        accountname TEXT NOT NULL,
        accounttype TEXT DEFAULT 'OTHER',
        bank_details TEXT DEFAULT '[]',
        address_line1 TEXT DEFAULT '',
        address_line2 TEXT DEFAULT '',
        city TEXT DEFAULT '',
        state TEXT DEFAULT '',
        country TEXT DEFAULT 'India',
        pincode TEXT DEFAULT '',
        phone_no TEXT DEFAULT '',
        email TEXT DEFAULT '',
        active INTEGER DEFAULT 1,
        gstno TEXT DEFAULT '',
        panno TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS account_head_options (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        option_type TEXT NOT NULL,
        option_value TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(option_type, option_value)
      );

      CREATE TABLE IF NOT EXISTS tax_master (
        taxid INTEGER PRIMARY KEY AUTOINCREMENT,
        taxcode TEXT NOT NULL UNIQUE,
        taxname TEXT NOT NULL,
        sgst_per REAL DEFAULT 0.0,
        sgstacname TEXT DEFAULT '',
        cgst_per REAL DEFAULT 0.0,
        cgstacname TEXT DEFAULT '',
        igst_per REAL DEFAULT 0.0,
        igstacname TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT DEFAULT '',
        details TEXT DEFAULT '',
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS designers (
        designerid INTEGER PRIMARY KEY AUTOINCREMENT,
        accode TEXT NOT NULL DEFAULT '',
        designername TEXT NOT NULL,
        designershortname TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS diamondpricesetting (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        companyid TEXT DEFAULT '',
        branchid TEXT DEFAULT '',
        productid INTEGER NOT NULL,
        subproductid INTEGER DEFAULT NULL,
        accode TEXT NOT NULL,
        from_cent REAL NOT NULL DEFAULT 0.0,
        to_cent REAL NOT NULL DEFAULT 0.0,
        cent_rate REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (productid) REFERENCES products(productid),
        FOREIGN KEY (subproductid) REFERENCES subproducts(subproductid)
      );

      CREATE TABLE IF NOT EXISTS prepare_sku_lots (
        lot_id INTEGER PRIMARY KEY AUTOINCREMENT,
        lot_number TEXT UNIQUE NOT NULL,
        companyid TEXT NOT NULL,
        branchid TEXT NOT NULL,
        designerid INTEGER NOT NULL,
        productid INTEGER NOT NULL,
        subproductid INTEGER,
        purityid INTEGER NOT NULL,
        rate REAL DEFAULT 0.0,
        is_assorted TEXT NOT NULL DEFAULT 'NO',
        total_pcs INTEGER NOT NULL DEFAULT 1,
        total_gross_weight REAL NOT NULL DEFAULT 0.0,
        total_net_weight REAL NOT NULL DEFAULT 0.0,
        
        -- Stone Details (Optional / multi-items)
        stone_productid INTEGER,
        stone_subproductid INTEGER,
        stone_unit TEXT DEFAULT 'G',
        total_stone_pcs INTEGER DEFAULT 0,
        total_stone_weight REAL DEFAULT 0.0,
        total_stone_amount REAL DEFAULT 0.0,
        stone_items_json TEXT DEFAULT '[]',
        
        -- Diamond Details (Optional / multi-items)
        diamond_productid INTEGER,
        diamond_subproductid INTEGER,
        diamond_unit TEXT DEFAULT 'C',
        total_diamond_pcs INTEGER DEFAULT 0,
        total_diamond_weight REAL DEFAULT 0.0,
        total_diamond_amount REAL DEFAULT 0.0,
        diamond_items_json TEXT DEFAULT '[]',
        
        is_active INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'PENDING_SKU',
        remarks TEXT DEFAULT '',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS prepare_sku_lot_stones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lot_id INTEGER NOT NULL,
        stone_productid INTEGER NOT NULL,
        stone_subproductid INTEGER,
        stone_unit TEXT DEFAULT 'G',
        pcs INTEGER DEFAULT 0,
        weight REAL DEFAULT 0.0,
        rate REAL DEFAULT 0.0,
        amount REAL DEFAULT 0.0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (lot_id) REFERENCES prepare_sku_lots(lot_id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS prepare_sku_lot_diamonds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lot_id INTEGER NOT NULL,
        diamond_productid INTEGER NOT NULL,
        diamond_subproductid INTEGER,
        diamond_unit TEXT DEFAULT 'C',
        pcs INTEGER DEFAULT 0,
        weight REAL DEFAULT 0.0,
        rate REAL DEFAULT 0.0,
        amount REAL DEFAULT 0.0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (lot_id) REFERENCES prepare_sku_lots(lot_id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS barcode_templates (
        template_id INTEGER PRIMARY KEY AUTOINCREMENT,
        companyid TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        width_mm REAL NOT NULL DEFAULT 80.0,
        height_mm REAL NOT NULL DEFAULT 13.0,
        unit TEXT NOT NULL DEFAULT 'mm',
        labels_per_row INTEGER NOT NULL DEFAULT 2,
        gap_mm REAL DEFAULT 2.0,
        margin_top_mm REAL DEFAULT 1.0,
        margin_left_mm REAL DEFAULT 1.0,
        tag_style TEXT NOT NULL DEFAULT 'JEWELRY_BUTTERFLY',
        is_default INTEGER DEFAULT 0,
        elements_json TEXT NOT NULL DEFAULT '[]',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS stock_tagged_items (
        item_id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku_code TEXT UNIQUE NOT NULL,
        lot_id INTEGER NOT NULL,
        lot_number TEXT NOT NULL,
        companyid TEXT NOT NULL,
        branchid TEXT NOT NULL,
        designerid INTEGER NOT NULL,
        productid INTEGER NOT NULL,
        subproductid INTEGER,
        styleid INTEGER,
        stylename TEXT DEFAULT '',
        sizeid INTEGER,
        sizename TEXT DEFAULT '',
        purityid INTEGER NOT NULL,
        pcs INTEGER NOT NULL DEFAULT 1,
        gross_weight REAL NOT NULL DEFAULT 0.0,
        net_weight REAL NOT NULL DEFAULT 0.0,
        stone_pcs INTEGER DEFAULT 0,
        stone_weight REAL DEFAULT 0.0,
        stone_amt REAL DEFAULT 0.0,
        stone_details_json TEXT DEFAULT '[]',
        diamond_pcs INTEGER DEFAULT 0,
        diamond_weight REAL DEFAULT 0.0,
        diamond_amt REAL DEFAULT 0.0,
        diamond_details_json TEXT DEFAULT '[]',
        board_rate REAL DEFAULT 0.0,
        sales_va_percent REAL DEFAULT 0.0,
        sales_wastage REAL DEFAULT 0.0,
        sales_mc_per_gram REAL DEFAULT 0.0,
        sales_m_charge REAL DEFAULT 0.0,
        sales_total_amt REAL DEFAULT 0.0,
        purchase_touch_pct REAL DEFAULT 0.0,
        purchase_gold_rate REAL DEFAULT 0.0,
        purchase_mc REAL DEFAULT 0.0,
        purchase_stone_cost REAL DEFAULT 0.0,
        purchase_diamond_cost REAL DEFAULT 0.0,
        purchase_total_cost REAL DEFAULT 0.0,
        huid TEXT DEFAULT '',
        status TEXT NOT NULL DEFAULT 'IN_STOCK',
        tag_printed_count INTEGER DEFAULT 0,
        tag_last_printed_at DATETIME,
        remarks TEXT DEFAULT '',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    `;

    await client.executeMultiple(createTablesSql);

    // --- SAFE NON-DESTRUCTIVE COLUMN MIGRATIONS (Concurrent parallel execution) ---
    const safeAddColumns = [
      // Categories migrations
      `ALTER TABLE categories ADD COLUMN purityid INTEGER;`,
      `ALTER TABLE categories ADD COLUMN sales_accode TEXT DEFAULT '';`,
      `ALTER TABLE categories ADD COLUMN purchase_accode TEXT DEFAULT '';`,
      `ALTER TABLE categories ADD COLUMN sgst_accode TEXT DEFAULT '';`,
      `ALTER TABLE categories ADD COLUMN cgst_accode TEXT DEFAULT '';`,
      `ALTER TABLE categories ADD COLUMN igst_accode TEXT DEFAULT '';`,
      `ALTER TABLE categories ADD COLUMN salesacname TEXT DEFAULT '';`,
      `ALTER TABLE categories ADD COLUMN purchaseacname TEXT DEFAULT '';`,
      `ALTER TABLE categories ADD COLUMN sgstacname TEXT DEFAULT '';`,
      `ALTER TABLE categories ADD COLUMN cgstacname TEXT DEFAULT '';`,
      `ALTER TABLE categories ADD COLUMN igstacname TEXT DEFAULT '';`,
      // Products migrations
      `ALTER TABLE products ADD COLUMN calctype TEXT DEFAULT 'WEIGHT';`,
      `ALTER TABLE products ADD COLUMN stocktype TEXT DEFAULT 'SKU';`,
      `ALTER TABLE products ADD COLUMN havestone_diamond TEXT DEFAULT 'NO';`,
      `ALTER TABLE products ADD COLUMN havesubproduct TEXT DEFAULT 'NO';`,
      `ALTER TABLE products ADD COLUMN studded TEXT DEFAULT 'N';`,
      `ALTER TABLE products ADD COLUMN diastone TEXT DEFAULT '';`,
      `ALTER TABLE products ADD COLUMN hsncode TEXT DEFAULT '';`,
      `ALTER TABLE products ADD COLUMN stoneunit TEXT DEFAULT '';`,
      // Subproducts migrations
      `ALTER TABLE subproducts ADD COLUMN havestone_diamond TEXT DEFAULT 'NO';`,
      // Customers migrations
      `ALTER TABLE customers ADD COLUMN pan_number TEXT DEFAULT '';`,
      `ALTER TABLE customers ADD COLUMN gstin TEXT DEFAULT '';`,
      `ALTER TABLE customers ADD COLUMN opening_balance REAL DEFAULT 0.0;`,
      `ALTER TABLE customers ADD COLUMN current_balance REAL DEFAULT 0.0;`,
      `ALTER TABLE customers ADD COLUMN notes TEXT DEFAULT '';`,
      // Invoices migrations
      `ALTER TABLE invoices ADD COLUMN customer_phone TEXT DEFAULT '';`,
      `ALTER TABLE invoices ADD COLUMN subtotal REAL DEFAULT 0.0;`,
      `ALTER TABLE invoices ADD COLUMN making_charges REAL DEFAULT 0.0;`,
      `ALTER TABLE invoices ADD COLUMN gst_percent REAL DEFAULT 3.0;`,
      `ALTER TABLE invoices ADD COLUMN gst_amount REAL DEFAULT 0.0;`,
      `ALTER TABLE invoices ADD COLUMN discount REAL DEFAULT 0.0;`,
      // Organization Profile migrations
      `ALTER TABLE organization_profile ADD COLUMN currency_symbol TEXT DEFAULT '₹';`,
      `ALTER TABLE organization_profile ADD COLUMN tagline TEXT DEFAULT 'Fine Gold & Bullion Jewelers';`,
      `ALTER TABLE organization_profile ADD COLUMN phone TEXT DEFAULT '';`,
      `ALTER TABLE organization_profile ADD COLUMN email TEXT DEFAULT '';`,
      `ALTER TABLE organization_profile ADD COLUMN address TEXT DEFAULT '';`,
      `ALTER TABLE organization_profile ADD COLUMN city TEXT DEFAULT '';`,
      `ALTER TABLE organization_profile ADD COLUMN state TEXT DEFAULT '';`,
      `ALTER TABLE organization_profile ADD COLUMN pincode TEXT DEFAULT '';`,
      `ALTER TABLE organization_profile ADD COLUMN gstin TEXT DEFAULT '';`,
      `ALTER TABLE organization_profile ADD COLUMN pan_number TEXT DEFAULT '';`,
      // Company migrations
      `ALTER TABLE company ADD COLUMN state_id INTEGER DEFAULT 0;`,
      `ALTER TABLE company ADD COLUMN country_id INTEGER DEFAULT 1;`,
      `ALTER TABLE company ADD COLUMN accountname TEXT DEFAULT '';`,
      `ALTER TABLE company ADD COLUMN branchid TEXT DEFAULT '';`,
      // Branches migrations
      `ALTER TABLE branches ADD COLUMN state_id INTEGER DEFAULT 0;`,
      `ALTER TABLE branches ADD COLUMN country_id INTEGER DEFAULT 1;`,
      `ALTER TABLE branches ADD COLUMN is_active INTEGER DEFAULT 1;`,
      `ALTER TABLE branches ADD COLUMN accountname TEXT DEFAULT '';`,
      // Users migrations
      `ALTER TABLE users ADD COLUMN centlogin TEXT DEFAULT 'NO';`,
      `ALTER TABLE users ADD COLUMN profile_image TEXT DEFAULT '';`,
      `ALTER TABLE users ADD COLUMN allowed_menus TEXT DEFAULT '[]';`,
      `ALTER TABLE users ADD COLUMN email TEXT DEFAULT '';`,
      `ALTER TABLE users ADD COLUMN branchid TEXT DEFAULT '';`,
      `ALTER TABLE users ADD COLUMN is_active INTEGER DEFAULT 1;`,
      // Employees migrations
      `ALTER TABLE employees ADD COLUMN dateofjoin TEXT DEFAULT '';`,
      `ALTER TABLE employees ADD COLUMN active INTEGER DEFAULT 1;`,
      `ALTER TABLE employees ADD COLUMN bloodgroup TEXT DEFAULT '';`,
      `ALTER TABLE employees ADD COLUMN mobile TEXT DEFAULT '';`,
      `ALTER TABLE employees ADD COLUMN email TEXT DEFAULT '';`,
      `ALTER TABLE employees ADD COLUMN address TEXT DEFAULT '';`,
      `ALTER TABLE employees ADD COLUMN image TEXT DEFAULT '';`,
      // Account Heads migrations
      `ALTER TABLE account_heads ADD COLUMN accounttype TEXT DEFAULT 'OTHER';`,
      `ALTER TABLE account_heads ADD COLUMN bank_details TEXT DEFAULT '[]';`,
      `ALTER TABLE account_heads ADD COLUMN address_line1 TEXT DEFAULT '';`,
      `ALTER TABLE account_heads ADD COLUMN address_line2 TEXT DEFAULT '';`,
      `ALTER TABLE account_heads ADD COLUMN city TEXT DEFAULT '';`,
      `ALTER TABLE account_heads ADD COLUMN state TEXT DEFAULT '';`,
      `ALTER TABLE account_heads ADD COLUMN country TEXT DEFAULT 'India';`,
      `ALTER TABLE account_heads ADD COLUMN pincode TEXT DEFAULT '';`,
      `ALTER TABLE account_heads ADD COLUMN phone_no TEXT DEFAULT '';`,
      `ALTER TABLE account_heads ADD COLUMN email TEXT DEFAULT '';`,
      `ALTER TABLE account_heads ADD COLUMN active INTEGER DEFAULT 1;`,
      `ALTER TABLE account_heads ADD COLUMN gstno TEXT DEFAULT '';`,
      `ALTER TABLE account_heads ADD COLUMN panno TEXT DEFAULT '';`,
      // Tax Master migrations
      `ALTER TABLE tax_master ADD COLUMN sgst_per REAL DEFAULT 0.0;`,
      `ALTER TABLE tax_master ADD COLUMN sgstacname TEXT DEFAULT '';`,
      `ALTER TABLE tax_master ADD COLUMN cgst_per REAL DEFAULT 0.0;`,
      `ALTER TABLE tax_master ADD COLUMN cgstacname TEXT DEFAULT '';`,
      `ALTER TABLE tax_master ADD COLUMN igst_per REAL DEFAULT 0.0;`,
      `ALTER TABLE tax_master ADD COLUMN igstacname TEXT DEFAULT '';`,
      // Daily Rates migrations
      `ALTER TABLE daily_rates ADD COLUMN batch_id INTEGER DEFAULT 1;`,
      `ALTER TABLE daily_rates ADD COLUMN buy_rate REAL DEFAULT 0.0;`,
      `ALTER TABLE daily_rates ADD COLUMN sell_rate REAL DEFAULT 0.0;`,
      `ALTER TABLE daily_rates ADD COLUMN notes TEXT DEFAULT '';`,
      // System Controls migrations
      `ALTER TABLE system_controls ADD COLUMN ctlid TEXT;`,
      `ALTER TABLE system_controls ADD COLUMN ctlname TEXT;`,
      `ALTER TABLE system_controls ADD COLUMN ctlvalue TEXT;`,
      `ALTER TABLE system_controls ADD COLUMN module TEXT;`,
      `ALTER TABLE system_controls ADD COLUMN branch_id TEXT DEFAULT 'ALL';`,
      // Estimates migrations
      `ALTER TABLE estimates ADD COLUMN estimate_no TEXT;`,
      `ALTER TABLE estimates ADD COLUMN customer_mobile TEXT DEFAULT '';`,
      `ALTER TABLE estimates ADD COLUMN customer_address TEXT DEFAULT '';`,
      `ALTER TABLE estimates ADD COLUMN employee_id INTEGER;`,
      `ALTER TABLE estimates ADD COLUMN employee_code TEXT DEFAULT '';`,
      `ALTER TABLE estimates ADD COLUMN employee_name TEXT DEFAULT '';`,
      `ALTER TABLE estimates ADD COLUMN gross_weight REAL DEFAULT 0.0;`,
      `ALTER TABLE estimates ADD COLUMN net_weight REAL DEFAULT 0.0;`,
      `ALTER TABLE estimates ADD COLUMN total_metal_value REAL DEFAULT 0.0;`,
      `ALTER TABLE estimates ADD COLUMN total_making_charges REAL DEFAULT 0.0;`,
      `ALTER TABLE estimates ADD COLUMN total_stone_charges REAL DEFAULT 0.0;`,
      `ALTER TABLE estimates ADD COLUMN total_diamond_charges REAL DEFAULT 0.0;`,
      `ALTER TABLE estimates ADD COLUMN total_va_charges REAL DEFAULT 0.0;`,
      `ALTER TABLE estimates ADD COLUMN taxable_amount REAL DEFAULT 0.0;`,
      `ALTER TABLE estimates ADD COLUMN gst_rate REAL DEFAULT 3.0;`,
      `ALTER TABLE estimates ADD COLUMN tax_amount REAL DEFAULT 0.0;`,
      `ALTER TABLE estimates ADD COLUMN net_amount REAL DEFAULT 0.0;`,
      `ALTER TABLE estimates ADD COLUMN items_json TEXT DEFAULT '[]';`,
      `ALTER TABLE estimates ADD COLUMN notes TEXT DEFAULT '';`,
      `ALTER TABLE estimates ADD COLUMN updated_at TEXT;`,
      // Stock tagged items migrations
      `ALTER TABLE stock_tagged_items ADD COLUMN styleid INTEGER;`,
      `ALTER TABLE stock_tagged_items ADD COLUMN stylename TEXT DEFAULT '';`,
      `ALTER TABLE stock_tagged_items ADD COLUMN sizeid INTEGER;`,
      `ALTER TABLE stock_tagged_items ADD COLUMN sizename TEXT DEFAULT '';`,
      // Designers migrations
      `ALTER TABLE designers ADD COLUMN accode TEXT DEFAULT '';`,
      `ALTER TABLE designers ADD COLUMN designershortname TEXT DEFAULT '';`,
      // Diamond Price Setting migrations
      `ALTER TABLE diamondpricesetting ADD COLUMN branchid TEXT DEFAULT '';`,
      `ALTER TABLE diamondpricesetting ADD COLUMN companyid TEXT DEFAULT '';`,
      `ALTER TABLE diamondpricesetting ADD COLUMN subproductid INTEGER DEFAULT NULL;`,
      `ALTER TABLE diamondpricesetting ADD COLUMN from_cent REAL DEFAULT 0.0;`,
      `ALTER TABLE diamondpricesetting ADD COLUMN to_cent REAL DEFAULT 0.0;`,
      `ALTER TABLE diamondpricesetting ADD COLUMN cent_rate REAL DEFAULT 0.0;`,
      // Prepare SKU Lots migrations
      `ALTER TABLE prepare_sku_lots ADD COLUMN stone_unit TEXT DEFAULT 'G';`,
      `ALTER TABLE prepare_sku_lots ADD COLUMN diamond_unit TEXT DEFAULT 'C';`,
      `ALTER TABLE prepare_sku_lots ADD COLUMN stone_items_json TEXT DEFAULT '[]';`,
      `ALTER TABLE prepare_sku_lots ADD COLUMN diamond_items_json TEXT DEFAULT '[]';`,
      `ALTER TABLE prepare_sku_lots ADD COLUMN total_stone_amount REAL DEFAULT 0.0;`,
      `ALTER TABLE prepare_sku_lots ADD COLUMN total_diamond_amount REAL DEFAULT 0.0;`,
      `ALTER TABLE prepare_sku_lots ADD COLUMN is_active INTEGER DEFAULT 1;`,
      `ALTER TABLE prepare_sku_lots ADD COLUMN is_assorted TEXT DEFAULT 'NO';`,
      `ALTER TABLE prepare_sku_lots ADD COLUMN rate REAL DEFAULT 0.0;`,
    ];

    // Execute safe column additions in sequential batches to avoid SQLITE_BUSY table locks
    for (const alterSql of safeAddColumns) {
      try {
        await client.execute(alterSql);
      } catch (_) {}
    }

    // --- PERFORMANCE INDEXES (Concurrent batch execution) ---
    const indexes = [
      `CREATE INDEX IF NOT EXISTS idx_products_categoryid ON products (categoryid);`,
      `CREATE UNIQUE INDEX IF NOT EXISTS idx_products_productname_unique ON products (UPPER(TRIM(productname)));`,
      `CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers (phone);`,
      `CREATE INDEX IF NOT EXISTS idx_invoices_number ON invoices (invoice_number);`,
      `CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices (customer_id);`,
      `CREATE INDEX IF NOT EXISTS idx_invoice_items_inv ON invoice_items (invoice_id);`,
      `CREATE INDEX IF NOT EXISTS idx_payments_customer ON payments (customer_id);`,
      `CREATE INDEX IF NOT EXISTS idx_account_heads_accode ON account_heads (accode);`,
      `CREATE INDEX IF NOT EXISTS idx_tax_master_taxcode ON tax_master (taxcode);`,
      `CREATE INDEX IF NOT EXISTS idx_daily_rates_purity_id ON daily_rates (purityid, id DESC);`,
      `CREATE INDEX IF NOT EXISTS idx_company_companyname ON company (companyname);`,
      `CREATE INDEX IF NOT EXISTS idx_branches_companyid ON branches (companyid);`,
      `CREATE INDEX IF NOT EXISTS idx_stock_tags_sku ON stock_tagged_items (sku_code);`,
      `CREATE INDEX IF NOT EXISTS idx_stock_tags_lot ON stock_tagged_items (lot_id);`,
      `CREATE INDEX IF NOT EXISTS idx_stock_tags_company ON stock_tagged_items (companyid);`,
      `CREATE INDEX IF NOT EXISTS idx_stock_tags_branch ON stock_tagged_items (branchid);`,
      `CREATE INDEX IF NOT EXISTS idx_stock_tags_status ON stock_tagged_items (status);`,
      `CREATE INDEX IF NOT EXISTS idx_prepare_sku_lots_num ON prepare_sku_lots (lot_number);`,
      `CREATE INDEX IF NOT EXISTS idx_designers_name ON designers (designername);`,
      `CREATE UNIQUE INDEX IF NOT EXISTS idx_designers_designername_unique ON designers (UPPER(TRIM(designername)));`,
      `CREATE INDEX IF NOT EXISTS idx_diamond_price_product ON diamondpricesetting (productid);`,
    ];

    try {
      await client.executeMultiple(indexes.join("\n"));
    } catch (_) {
      await Promise.allSettled(indexes.map((indexSql) => client.execute(indexSql).catch(() => {})));
    }

    // --- INITIAL SEED DATA (If empty) ---
    const now = new Date().toISOString();

    // Seed Organization Profile
    try {
      const orgCheck = await client.execute(`SELECT COUNT(*) as cnt FROM organization_profile;`);
      if (Number(orgCheck.rows[0]?.cnt || 0) === 0) {
        await client.execute({
          sql: `INSERT INTO organization_profile (business_name, tagline, currency_symbol, created_at, updated_at) VALUES (?, ?, ?, ?, ?)`,
          args: ["ProGold Enterprise", "Fine Gold & Bullion Jewelers", "₹", now, now],
        });
      }
    } catch (_) { }

    // Seed Metals, Purities, and Categories
    try {
      const metalCheck = await client.execute(`SELECT COUNT(*) as cnt FROM metals;`);
      if (Number(metalCheck.rows[0]?.cnt || 0) === 0) {
        // Seed metals
        await client.execute(`
          INSERT INTO metals (metalid, metalname, created_at, updated_at) VALUES
          ('G', 'Gold', '${now}', '${now}'),
          ('S', 'Silver', '${now}', '${now}'),
          ('P', 'Platinum', '${now}', '${now}');
        `);

        // Seed purities
        await client.execute(`
          INSERT INTO purities (metalid, purityname, purityshortname, purity, type, created_at, updated_at) VALUES
          ('G', '24K Gold', '24K', 99.9, 'METAL', '${now}', '${now}'),
          ('G', '22K Gold', '22K', 91.6, 'ORNAMENT', '${now}', '${now}'),
          ('G', '18K Gold', '18K', 75.0, 'ORNAMENT', '${now}', '${now}'),
          ('S', 'Fine Silver', 'Fine', 99.9, 'METAL', '${now}', '${now}'),
          ('S', 'Standard Silver', '92.5', 92.5, 'ORNAMENT', '${now}', '${now}');
        `);

        // Seed categories
        await client.execute(`
          INSERT INTO categories (metalid, catcode, catname, categorytype, sgst_per, cgst_per, igst_per, created_at, updated_at) VALUES
          ('G', 'GO00001', 'Gold Ornaments GST', 'ORNAMENTS/STONE', 1.5, 1.5, 3.0, '${now}', '${now}'),
          ('G', 'GM00001', 'Gold Bar', 'METAL', 1.5, 1.5, 3.0, '${now}', '${now}'),
          ('S', 'SO00001', 'Silver Articles', 'ORNAMENTS/STONE', 1.5, 1.5, 3.0, '${now}', '${now}');
        `);
      }
    } catch (_) { }

    // Seed Default Gold Rates
    try {
      const rateCheck = await client.execute(`SELECT COUNT(*) as cnt FROM gold_rates;`);
      if (Number(rateCheck.rows[0]?.cnt || 0) === 0) {
        await client.execute(`
          INSERT INTO gold_rates (purity_name, purity_karat, purity_percent, buy_rate, sell_rate, silver_rate, updated_at) VALUES
          ('24K Fine Gold (99.9%)', 24, 99.9, 7450.0, 7550.0, 92.5, '${now}'),
          ('22K Standard Gold (91.6%)', 22, 91.6, 6830.0, 6925.0, 92.5, '${now}'),
          ('18K Hallmarked Gold (75.0%)', 18, 75.0, 5585.0, 5660.0, 92.5, '${now}');
        `);
      }
    } catch (_) { }

    // Seed Default Barcode Templates (if empty)
    try {
      const tmplCheck = await client.execute(`SELECT COUNT(*) as cnt FROM barcode_templates;`);
      if (Number(tmplCheck.rows[0]?.cnt || 0) === 0) {
        const defaultButterflyElements = JSON.stringify([
          { id: "elem_qr", type: "barcode_2d", field_key: "sku", label_prefix: "", format_template: "{sku}", x_mm: 1.5, y_mm: 1.5, width_mm: 10.0, height_mm: 10.0, font_size: 8, font_weight: "normal", alignment: "center", is_bold: false, is_visible: true },
          { id: "elem_comp", type: "text", field_key: "company_name", label_prefix: "", format_template: "{company_name}", x_mm: 12.5, y_mm: 1.0, width_mm: 25.0, height_mm: 3.5, font_size: 7, font_weight: "bold", alignment: "left", is_bold: true, is_visible: true },
          { id: "elem_item", type: "text", field_key: "product_name", label_prefix: "", format_template: "{product_name}", x_mm: 12.5, y_mm: 4.5, width_mm: 25.0, height_mm: 3.0, font_size: 6, font_weight: "normal", alignment: "left", is_bold: false, is_visible: true },
          { id: "elem_purity", type: "text", field_key: "purity", label_prefix: "", format_template: "{purity}", x_mm: 12.5, y_mm: 7.5, width_mm: 25.0, height_mm: 3.0, font_size: 6, font_weight: "bold", alignment: "left", is_bold: true, is_visible: true },
          { id: "elem_grs", type: "text", field_key: "gross_weight", label_prefix: "GRS: ", format_template: "GRS: {gross_weight}g", x_mm: 40.0, y_mm: 1.0, width_mm: 38.0, height_mm: 3.5, font_size: 6.5, font_weight: "bold", alignment: "left", is_bold: true, is_visible: true },
          { id: "elem_net", type: "text", field_key: "net_weight", label_prefix: "NET: ", format_template: "NET: {net_weight}g", x_mm: 40.0, y_mm: 4.5, width_mm: 38.0, height_mm: 3.0, font_size: 6, font_weight: "normal", alignment: "left", is_bold: false, is_visible: true },
          { id: "elem_stone", type: "text", field_key: "stone_info", label_prefix: "S: ", format_template: "S: {stone_pcs}/{stone_weight}g", x_mm: 40.0, y_mm: 7.5, width_mm: 38.0, height_mm: 2.5, font_size: 5.5, font_weight: "normal", alignment: "left", is_bold: false, is_visible: true },
          { id: "elem_dmd", type: "text", field_key: "diamond_info", label_prefix: "D: ", format_template: "D: {diamond_pcs}/{diamond_weight}ct", x_mm: 40.0, y_mm: 10.0, width_mm: 38.0, height_mm: 2.5, font_size: 5.5, font_weight: "normal", alignment: "left", is_bold: false, is_visible: true },
        ]);

        const defaultRetailElements = JSON.stringify([
          { id: "elem_comp", type: "text", field_key: "company_name", label_prefix: "", format_template: "{company_name}", x_mm: 2.0, y_mm: 1.5, width_mm: 46.0, height_mm: 3.5, font_size: 8, font_weight: "bold", alignment: "center", is_bold: true, is_visible: true },
          { id: "elem_barcode", type: "barcode_1d", field_key: "sku", label_prefix: "", format_template: "{sku}", x_mm: 2.0, y_mm: 5.0, width_mm: 46.0, height_mm: 8.5, font_size: 7, font_weight: "normal", alignment: "center", is_bold: false, is_visible: true },
          { id: "elem_sku_txt", type: "text", field_key: "sku", label_prefix: "SKU: ", format_template: "{sku}", x_mm: 2.0, y_mm: 14.0, width_mm: 46.0, height_mm: 3.0, font_size: 6.5, font_weight: "normal", alignment: "center", is_bold: false, is_visible: true },
          { id: "elem_grs", type: "text", field_key: "gross_weight", label_prefix: "GRSWT: ", format_template: "GRSWT: {gross_weight}g", x_mm: 2.0, y_mm: 17.5, width_mm: 23.0, height_mm: 3.0, font_size: 6.5, font_weight: "bold", alignment: "left", is_bold: true, is_visible: true },
          { id: "elem_purity", type: "text", field_key: "purity", label_prefix: "", format_template: "{purity}", x_mm: 25.0, y_mm: 17.5, width_mm: 23.0, height_mm: 3.0, font_size: 6.5, font_weight: "bold", alignment: "right", is_bold: true, is_visible: true },
          { id: "elem_stones", type: "text", field_key: "stone_info", label_prefix: "S: ", format_template: "S: {stone_pcs}/{stone_weight}g", x_mm: 2.0, y_mm: 21.0, width_mm: 23.0, height_mm: 3.0, font_size: 5.5, font_weight: "normal", alignment: "left", is_bold: false, is_visible: true },
          { id: "elem_dmd", type: "text", field_key: "diamond_info", label_prefix: "D: ", format_template: "D: {diamond_pcs}/{diamond_weight}ct", x_mm: 25.0, y_mm: 21.0, width_mm: 23.0, height_mm: 3.0, font_size: 5.5, font_weight: "normal", alignment: "right", is_bold: false, is_visible: true },
        ]);

        await client.execute({
          sql: `INSERT INTO barcode_templates (name, width_mm, height_mm, unit, labels_per_row, gap_mm, margin_top_mm, margin_left_mm, tag_style, is_default, elements_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          args: ["Jewelry Butterfly Tag (80x13mm, 2-Across)", 80.0, 13.0, "mm", 2, 3.0, 1.0, 1.5, "JEWELRY_BUTTERFLY", 1, defaultButterflyElements, now, now],
        });

        await client.execute({
          sql: `INSERT INTO barcode_templates (name, width_mm, height_mm, unit, labels_per_row, gap_mm, margin_top_mm, margin_left_mm, tag_style, is_default, elements_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          args: ["Standard Retail Barcode (50x25mm, 1-Across)", 50.0, 25.0, "mm", 1, 2.0, 1.5, 1.5, "RECTANGLE", 0, defaultRetailElements, now, now],
        });
      }
    } catch (_) { }

    // Record migration entry
    try {
      await client.execute({
        sql: `INSERT INTO schema_migrations (version, migration_name, applied_at) VALUES (?, ?, ?)`,
        args: ["2.0.0", "ProGold ERP Full Schema & Index Sync", now],
      });
    } catch (_) { }

    // Count installed tables
    const tableOverview = await getPostgresTenantDatabaseOverview(schemaName);
    const tablesCount = tableOverview.tables.length;
    const executionTimeMs = Date.now() - startTime;

    return {
      success: true,
      message: `ProGold ERP database schema successfully installed and synchronized! (${tablesCount} tables ready, ${executionTimeMs}ms)`,
      tablesCount,
      executionTimeMs,
      appliedAt: now,
      tables: tableOverview.tables,
    };
  } catch (error) {
    console.error("syncTenantDatabaseSchema error:", error);
    throw new Error(`Failed to install tenant schema: ${error?.message || "PostgreSQL error"}`, { cause: error });
  }
}
