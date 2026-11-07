import 'package:flutter/material.dart';

/// Standardized Menu & Submenu Registry for ProGold Jewellery Billing System
/// Use these exact Unique Code Identifiers to refer to any menu or submenu.

class MenuRegistry {
  // ==========================================
  // 1. MAJOR MENUS (MODULES)
  // ==========================================
  static const String MENU_MASTER = "M_MASTER";
  static const String MENU_SMITH_PURCHASE = "M_SMITH_PURCHASE";
  static const String MENU_STOCK = "M_STOCK";
  static const String MENU_ESTIMATE = "M_ESTIMATE";
  static const String MENU_POS = "M_POS";
  static const String MENU_REPORT = "M_REPORT";
  static const String MENU_DIGIGOLD = "M_DIGIGOLD";
  static const String MENU_SETTINGS = "M_SETTINGS";
  static const String MENU_CRM = "M_CRM";
  static const String MENU_MORE = "M_MORE";

  // ==========================================
  // 2. SUB-MENUS UNDER MASTER (M_MASTER)
  // ==========================================
  static const String MASTER_ORGANIZATION = "M_MASTER.ORGANIZATION";
  static const String MASTER_ORGANIZATION_COMPANY = "M_MASTER.ORGANIZATION.COMPANY";
  static const String MASTER_ORGANIZATION_BRANCHES = "M_MASTER.ORGANIZATION.BRANCHES";
  static const String MASTER_ORGANIZATION_USER_RIGHTS = "M_MASTER.ORGANIZATION.USER_RIGHTS";
  static const String MASTER_INVENTORY = "M_MASTER.INVENTORY";
  static const String MASTER_INVENTORY_METAL = "M_MASTER.INVENTORY.METAL";
  static const String MASTER_INVENTORY_PURITY = "M_MASTER.INVENTORY.PURITY";
  static const String MASTER_INVENTORY_CATEGORY = "M_MASTER.INVENTORY.CATEGORY";
  static const String MASTER_INVENTORY_DESIGNERS = "M_MASTER.INVENTORY.DESIGNERS";
  static const String MASTER_INVENTORY_PRODUCTS = "M_MASTER.INVENTORY.PRODUCTS";
  static const String MASTER_INVENTORY_SUBPRODUCTS = "M_MASTER.INVENTORY.SUBPRODUCTS";
  static const String MASTER_INVENTORY_STYLES = "M_MASTER.INVENTORY.STYLES";
  static const String MASTER_INVENTORY_SIZES = "M_MASTER.INVENTORY.SIZES";
  static const String MASTER_INVENTORY_PRICE_SETTING = "M_MASTER.INVENTORY.PRICE_SETTING";
  static const String MASTER_INVENTORY_DIAMOND_PRICE_SETTING = "M_MASTER.INVENTORY.DIAMOND_PRICE_SETTING";
  static const String MASTER_SALES_AND_PRICE = "M_MASTER.SALES_AND_PRICE";
  static const String MASTER_LOGIN_USERS = "M_MASTER.LOGIN_USERS";
  static const String MASTER_EMPLOYEES = "M_MASTER.EMPLOYEES";
  static const String MASTER_ACCOUNT_HEAD = "M_MASTER.ACCOUNT_HEAD";
  static const String MASTER_TAX_MASTER = "M_MASTER.TAX_MASTER";

  // ==========================================
  // 2b. SUB-MENUS UNDER SMITH PURCHASE (M_SMITH_PURCHASE)
  // ==========================================
  static const String SMITH_PURCHASE_ENTRY = "M_SMITH_PURCHASE.ENTRY";
  static const String SMITH_PURCHASE_REGISTER = "M_SMITH_PURCHASE.REGISTER";
  static const String SMITH_PURCHASE_RECEIPT = "M_SMITH_PURCHASE.RECEIPT";
  static const String SMITH_PURCHASE_SMITH_LEDGER = "M_SMITH_PURCHASE.SMITH_LEDGER";

  // ==========================================
  // 3. SUB-MENUS UNDER STOCK (M_STOCK) - Extensible
  // ==========================================
  static const String STOCK_PREPARE_FOR_SKU = "M_STOCK.PREPARE_FOR_SKU";
  static const String STOCK_LIVE_INVENTORY = "M_STOCK.LIVE_INVENTORY";
  static const String STOCK_ENTRY = "M_STOCK.ENTRY";
  static const String STOCK_BARCODE_TAGS = "M_STOCK.BARCODE_TAGS";
  static const String STOCK_AUDIT = "M_STOCK.AUDIT";

  // ==========================================
  // 4. SUB-MENUS UNDER ESTIMATE (M_ESTIMATE) - 3rd Main Menu
  // ==========================================
  static const String ESTIMATE_NEW = "M_ESTIMATE.NEW";
  static const String ESTIMATE_REGISTER = "M_ESTIMATE.REGISTER";
  static const String ESTIMATE_CONVERT = "M_ESTIMATE.CONVERT";

  // ==========================================
  // 5. SUB-MENUS UNDER POS (M_POS) - Extensible
  // ==========================================
  static const String POS_BILLING = "M_POS.BILLING";
  static const String POS_ESTIMATION = "M_POS.ESTIMATION";
  static const String POS_RETURN_EXCHANGE = "M_POS.RETURN_EXCHANGE";
  static const String POS_OLD_GOLD_PURCHASE = "M_POS.OLD_GOLD_PURCHASE";

  // ==========================================
  // 5. SUB-MENUS UNDER REPORT (M_REPORT) - Extensible
  // ==========================================
  static const String REPORT_SALES = "M_REPORT.SALES";
  static const String REPORT_DAYBOOK = "M_REPORT.DAYBOOK";
  static const String REPORT_STOCK_LEDGER = "M_REPORT.STOCK_LEDGER";
  static const String REPORT_GST_GSTR1 = "M_REPORT.GST_GSTR1";

  // ==========================================
  // 6. SUB-MENUS UNDER DIGIGOLD (M_DIGIGOLD) - Extensible
  // ==========================================
  static const String DIGIGOLD_VAULT = "M_DIGIGOLD.VAULT";
  static const String DIGIGOLD_BUY_SELL = "M_DIGIGOLD.BUY_SELL";
  static const String DIGIGOLD_SIP_PLANS = "M_DIGIGOLD.SIP_PLANS";

  // ==========================================
  // 7. SUB-MENUS UNDER SETTINGS (M_SETTINGS) - Extensible
  // ==========================================
  static const String SETTINGS_STORE = "M_SETTINGS.STORE";
  static const String SETTINGS_PRINTER = "M_SETTINGS.PRINTER";
  static const String SETTINGS_DB_STATUS = "M_SETTINGS.DB_STATUS";
  static const String SETTINGS_SYSTEM_CONTROLS = "M_SETTINGS.SYSTEM_CONTROLS";
  static const String SETTINGS_TURSO_SYNC = "M_SETTINGS.TURSO_SYNC";
  static const String SETTINGS_REINSTALL_SYNC = "M_SETTINGS.REINSTALL_SYNC";

  // ==========================================
  // 8. SUB-MENUS UNDER CRM (M_CRM) - Extensible
  // ==========================================
  static const String CRM_CUSTOMERS = "M_CRM.CUSTOMERS";
  static const String CRM_GOLD_SCHEMES = "M_CRM.GOLD_SCHEMES";
  static const String CRM_ALERTS_REMINDERS = "M_CRM.ALERTS_REMINDERS";
}

/// Metadata item for menu display
class MenuItemDef {
  final String code;
  final String name;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<MenuItemDef> submenus;

  const MenuItemDef({
    required this.code,
    required this.name,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.submenus = const [],
  });
}
