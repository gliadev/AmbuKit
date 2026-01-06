/**
 * AmbuKit - Firestore Security Rules Tests
 * 
 * Tests para verificar que las reglas de seguridad de Firestore
 * funcionan correctamente según la matriz de permisos de AmbuKit.
 * 
 * ROLES:
 *   - programmer: Acceso completo
 *   - logistics: CRUD bases/vehicles/kits, NO delete vehicles/kits
 *   - sanitary: Solo lectura + update stock kitItems
 * 
 * Ejecutar: npm test (con emulador corriendo)
 */

const { 
  initializeTestEnvironment, 
  assertFails, 
  assertSucceeds 
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

// ============================================================================
// CONFIGURACIÓN
// ============================================================================

const PROJECT_ID = 'demo-ambukit';
const RULES_PATH = path.join(__dirname, '..', 'firestore.rules');

let testEnv;

// ============================================================================
// SETUP / TEARDOWN
// ============================================================================

beforeAll(async () => {
  const rules = fs.readFileSync(RULES_PATH, 'utf8');
  
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: rules,
      host: '127.0.0.1',
      port: 8080
    }
  });
});

afterAll(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Crea un contexto autenticado para un usuario
 */
function getAuthContext(uid) {
  return testEnv.authenticatedContext(uid);
}

/**
 * Crea un contexto no autenticado
 */
function getUnauthContext() {
  return testEnv.unauthenticatedContext();
}

/**
 * Crea datos de prueba: roles y usuarios
 * Usa withSecurityRulesDisabled para bypasear las reglas
 */
async function setupTestData() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    
    // Crear roles
    await adminDb.collection('roles').doc('role_programmer').set({
      kind: 'programmer',
      displayName: 'Programador'
    });
    
    await adminDb.collection('roles').doc('role_logistics').set({
      kind: 'logistics',
      displayName: 'Logística'
    });
    
    await adminDb.collection('roles').doc('role_sanitary').set({
      kind: 'sanitary',
      displayName: 'Sanitario'
    });
    
    // Crear usuarios
    await adminDb.collection('users').doc('programmer_uid').set({
      uid: 'programmer_uid',
      username: 'admin',
      email: 'admin@ambukit.com',
      roleId: 'role_programmer',
      active: true
    });
    
    await adminDb.collection('users').doc('logistics_uid').set({
      uid: 'logistics_uid',
      username: 'logistica',
      email: 'logistica@ambukit.com',
      roleId: 'role_logistics',
      active: true
    });
    
    await adminDb.collection('users').doc('sanitary_uid').set({
      uid: 'sanitary_uid',
      username: 'sanitario',
      email: 'sanitario@ambukit.com',
      roleId: 'role_sanitary',
      active: true
    });
  });
}

/**
 * Helper para crear datos con admin context
 */
async function createWithAdmin(collection, docId, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection(collection).doc(docId).set(data);
  });
}

// ============================================================================
// TESTS: USUARIOS NO AUTENTICADOS
// ============================================================================

describe('Unauthenticated Access', () => {
  beforeEach(async () => {
    await setupTestData();
  });

  test('usuarios no autenticados NO pueden leer users', async () => {
    const db = getUnauthContext().firestore();
    await assertFails(db.collection('users').get());
  });

  test('usuarios no autenticados NO pueden leer roles', async () => {
    const db = getUnauthContext().firestore();
    await assertFails(db.collection('roles').get());
  });

  test('usuarios no autenticados NO pueden leer bases', async () => {
    const db = getUnauthContext().firestore();
    await assertFails(db.collection('bases').get());
  });

  test('usuarios no autenticados NO pueden leer kits', async () => {
    const db = getUnauthContext().firestore();
    await assertFails(db.collection('kits').get());
  });

  test('usuarios no autenticados NO pueden leer auditLogs', async () => {
    const db = getUnauthContext().firestore();
    await assertFails(db.collection('auditLogs').get());
  });
});

// ============================================================================
// TESTS: USERS COLLECTION
// ============================================================================

describe('Users Collection Security', () => {
  beforeEach(async () => {
    await setupTestData();
  });

  // READ
  test('todos los autenticados pueden leer users', async () => {
    const sanitaryDb = getAuthContext('sanitary_uid').firestore();
    await assertSucceeds(sanitaryDb.collection('users').get());
  });

  // CREATE
  test('programmer PUEDE crear users', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('users').doc('new_user').set({
        uid: 'new_user',
        username: 'nuevo',
        email: 'nuevo@ambukit.com',
        roleId: 'role_sanitary',
        active: true
      })
    );
  });

  test('logistics NO puede crear users', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertFails(
      db.collection('users').doc('new_user').set({
        uid: 'new_user',
        username: 'nuevo',
        email: 'nuevo@ambukit.com',
        roleId: 'role_sanitary',
        active: true
      })
    );
  });

  test('sanitary NO puede crear users', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('users').doc('new_user').set({
        uid: 'new_user',
        username: 'nuevo',
        email: 'nuevo@ambukit.com',
        roleId: 'role_sanitary',
        active: true
      })
    );
  });

  // UPDATE
  test('programmer PUEDE actualizar users', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('users').doc('sanitary_uid').update({
        username: 'sanitario_updated'
      })
    );
  });

  test('logistics NO puede actualizar users', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertFails(
      db.collection('users').doc('sanitary_uid').update({
        username: 'hack'
      })
    );
  });

  // DELETE
  test('programmer PUEDE eliminar users', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('users').doc('sanitary_uid').delete()
    );
  });

  test('logistics NO puede eliminar users', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertFails(
      db.collection('users').doc('sanitary_uid').delete()
    );
  });

  test('sanitary NO puede eliminar users', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('users').doc('logistics_uid').delete()
    );
  });
});

// ============================================================================
// TESTS: ROLES COLLECTION (Read-Only)
// ============================================================================

describe('Roles Collection Security', () => {
  beforeEach(async () => {
    await setupTestData();
  });

  test('todos los autenticados pueden leer roles', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertSucceeds(db.collection('roles').get());
  });

  test('NI programmer puede crear roles', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertFails(
      db.collection('roles').doc('new_role').set({
        kind: 'superadmin',
        displayName: 'Super Admin'
      })
    );
  });

  test('NI programmer puede eliminar roles', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertFails(
      db.collection('roles').doc('role_sanitary').delete()
    );
  });
});

// ============================================================================
// TESTS: POLICIES COLLECTION (Read-Only)
// ============================================================================

describe('Policies Collection Security', () => {
  beforeEach(async () => {
    await setupTestData();
    await createWithAdmin('policies', 'policy_test', {
      roleId: 'role_sanitary',
      entity: 'kit',
      canCreate: false,
      canRead: true,
      canUpdate: false,
      canDelete: false
    });
  });

  test('todos los autenticados pueden leer policies', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertSucceeds(db.collection('policies').get());
  });

  test('NI programmer puede modificar policies', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertFails(
      db.collection('policies').doc('policy_test').update({
        canCreate: true
      })
    );
  });
});

// ============================================================================
// TESTS: BASES COLLECTION
// ============================================================================

describe('Bases Collection Security', () => {
  beforeEach(async () => {
    await setupTestData();
    await createWithAdmin('bases', 'base_bilbao', {
      code: 'BIL001',
      name: 'Base Bilbao',
      vehicleIds: []
    });
  });

  // READ
  test('todos los autenticados pueden leer bases', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertSucceeds(db.collection('bases').get());
  });

  // CREATE
  test('programmer PUEDE crear bases', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('bases').doc('base_new').set({
        code: 'NEW001',
        name: 'Nueva Base',
        vehicleIds: []
      })
    );
  });

  test('logistics PUEDE crear bases', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertSucceeds(
      db.collection('bases').doc('base_log').set({
        code: 'LOG001',
        name: 'Base Logística',
        vehicleIds: []
      })
    );
  });

  test('sanitary NO puede crear bases', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('bases').doc('base_san').set({
        code: 'SAN001',
        name: 'Base Sanitario',
        vehicleIds: []
      })
    );
  });

  // UPDATE
  test('logistics PUEDE actualizar bases', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertSucceeds(
      db.collection('bases').doc('base_bilbao').update({
        name: 'Base Bilbao Updated'
      })
    );
  });

  test('sanitary NO puede actualizar bases', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('bases').doc('base_bilbao').update({
        name: 'Hack'
      })
    );
  });

  // DELETE
  test('programmer PUEDE eliminar bases', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('bases').doc('base_bilbao').delete()
    );
  });

  test('logistics NO puede eliminar bases', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertFails(
      db.collection('bases').doc('base_bilbao').delete()
    );
  });

  test('sanitary NO puede eliminar bases', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('bases').doc('base_bilbao').delete()
    );
  });
});

// ============================================================================
// TESTS: VEHICLES COLLECTION
// ============================================================================

describe('Vehicles Collection Security', () => {
  beforeEach(async () => {
    await setupTestData();
    await createWithAdmin('vehicles', 'amb_001', {
      code: 'AMB001',
      plate: '1234-BCD',
      type: 'SVA',
      baseId: 'base_bilbao',
      kitIds: []
    });
  });

  // READ
  test('todos los autenticados pueden leer vehicles', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertSucceeds(db.collection('vehicles').get());
  });

  // CREATE
  test('programmer PUEDE crear vehicles', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('vehicles').doc('amb_new').set({
        code: 'AMB002',
        plate: '5678-XYZ',
        type: 'SVB',
        baseId: null,
        kitIds: []
      })
    );
  });

  test('logistics PUEDE crear vehicles', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertSucceeds(
      db.collection('vehicles').doc('amb_log').set({
        code: 'AMB003',
        plate: '9999-LOG',
        type: 'VIR',
        baseId: null,
        kitIds: []
      })
    );
  });

  test('sanitary NO puede crear vehicles', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('vehicles').doc('amb_san').set({
        code: 'AMB004',
        plate: '0000-SAN',
        type: 'SVA',
        baseId: null,
        kitIds: []
      })
    );
  });

  // UPDATE
  test('logistics PUEDE actualizar vehicles', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertSucceeds(
      db.collection('vehicles').doc('amb_001').update({
        plate: '1234-UPD'
      })
    );
  });

  test('sanitary NO puede actualizar vehicles', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('vehicles').doc('amb_001').update({
        plate: 'HACK-001'
      })
    );
  });

  // DELETE - Solo programmer
  test('programmer PUEDE eliminar vehicles', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('vehicles').doc('amb_001').delete()
    );
  });

  test('logistics NO puede eliminar vehicles', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertFails(
      db.collection('vehicles').doc('amb_001').delete()
    );
  });

  test('sanitary NO puede eliminar vehicles', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('vehicles').doc('amb_001').delete()
    );
  });
});

// ============================================================================
// TESTS: KITS COLLECTION
// ============================================================================

describe('Kits Collection Security', () => {
  beforeEach(async () => {
    await setupTestData();
    await createWithAdmin('kits', 'kit_trauma', {
      code: 'KIT001',
      name: 'Kit Trauma',
      vehicleId: 'amb_001',
      itemIds: []
    });
  });

  // READ
  test('todos los autenticados pueden leer kits', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertSucceeds(db.collection('kits').get());
  });

  // CREATE
  test('programmer PUEDE crear kits', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('kits').doc('kit_new').set({
        code: 'KIT002',
        name: 'Kit Nuevo',
        vehicleId: null,
        itemIds: []
      })
    );
  });

  test('logistics PUEDE crear kits', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertSucceeds(
      db.collection('kits').doc('kit_log').set({
        code: 'KIT003',
        name: 'Kit Logística',
        vehicleId: null,
        itemIds: []
      })
    );
  });

  test('sanitary NO puede crear kits', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('kits').doc('kit_san').set({
        code: 'KIT004',
        name: 'Kit Sanitario',
        vehicleId: null,
        itemIds: []
      })
    );
  });

  // UPDATE
  test('logistics PUEDE actualizar kits', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertSucceeds(
      db.collection('kits').doc('kit_trauma').update({
        name: 'Kit Trauma Updated'
      })
    );
  });

  test('sanitary NO puede actualizar kits', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('kits').doc('kit_trauma').update({
        name: 'Hack'
      })
    );
  });

  // DELETE - Solo programmer
  test('programmer PUEDE eliminar kits', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('kits').doc('kit_trauma').delete()
    );
  });

  test('logistics NO puede eliminar kits', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertFails(
      db.collection('kits').doc('kit_trauma').delete()
    );
  });

  test('sanitary NO puede eliminar kits', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('kits').doc('kit_trauma').delete()
    );
  });
});

// ============================================================================
// TESTS: KIT ITEMS COLLECTION
// ============================================================================

describe('KitItems Collection Security', () => {
  beforeEach(async () => {
    await setupTestData();
    await createWithAdmin('kitItems', 'item_adrenalina', {
      catalogItemId: 'cat_adrenalina',
      kitId: 'kit_trauma',
      quantity: 10,
      min: 5,
      max: 20
    });
  });

  // READ
  test('todos los autenticados pueden leer kitItems', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertSucceeds(db.collection('kitItems').get());
  });

  // CREATE
  test('programmer PUEDE crear kitItems', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('kitItems').doc('item_new').set({
        catalogItemId: 'cat_xxx',
        kitId: 'kit_trauma',
        quantity: 5,
        min: 2,
        max: 10
      })
    );
  });

  test('logistics PUEDE crear kitItems', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertSucceeds(
      db.collection('kitItems').doc('item_log').set({
        catalogItemId: 'cat_yyy',
        kitId: 'kit_trauma',
        quantity: 3,
        min: 1,
        max: 5
      })
    );
  });

  test('sanitary NO puede crear kitItems', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('kitItems').doc('item_san').set({
        catalogItemId: 'cat_zzz',
        kitId: 'kit_trauma',
        quantity: 1,
        min: 1,
        max: 1
      })
    );
  });

  // UPDATE - Todos autenticados (sanitarios pueden actualizar stock)
  test('sanitary PUEDE actualizar stock (quantity)', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertSucceeds(
      db.collection('kitItems').doc('item_adrenalina').update({
        quantity: 8
      })
    );
  });

  test('logistics PUEDE actualizar umbrales (min/max)', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertSucceeds(
      db.collection('kitItems').doc('item_adrenalina').update({
        min: 3,
        max: 25
      })
    );
  });

  test('programmer PUEDE actualizar todo en kitItems', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('kitItems').doc('item_adrenalina').update({
        quantity: 15,
        min: 10,
        max: 30
      })
    );
  });

  // DELETE
  test('programmer PUEDE eliminar kitItems', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('kitItems').doc('item_adrenalina').delete()
    );
  });

  test('logistics PUEDE eliminar kitItems', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertSucceeds(
      db.collection('kitItems').doc('item_adrenalina').delete()
    );
  });

  test('sanitary NO puede eliminar kitItems', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('kitItems').doc('item_adrenalina').delete()
    );
  });
});

// ============================================================================
// TESTS: CATALOG ITEMS COLLECTION
// ============================================================================

describe('CatalogItems Collection Security', () => {
  beforeEach(async () => {
    await setupTestData();
    await createWithAdmin('catalogItems', 'cat_adrenalina', {
      code: 'ADR001',
      name: 'Adrenalina 1mg',
      critical: true
    });
  });

  // READ
  test('todos los autenticados pueden leer catalogItems', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertSucceeds(db.collection('catalogItems').get());
  });

  // CREATE
  test('programmer PUEDE crear catalogItems', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('catalogItems').doc('cat_new').set({
        code: 'NEW001',
        name: 'Nuevo Item',
        critical: false
      })
    );
  });

  test('logistics PUEDE crear catalogItems', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertSucceeds(
      db.collection('catalogItems').doc('cat_log').set({
        code: 'LOG001',
        name: 'Item Logística',
        critical: false
      })
    );
  });

  test('sanitary NO puede crear catalogItems', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('catalogItems').doc('cat_san').set({
        code: 'SAN001',
        name: 'Item Sanitario',
        critical: false
      })
    );
  });

  // UPDATE
  test('logistics PUEDE actualizar catalogItems', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertSucceeds(
      db.collection('catalogItems').doc('cat_adrenalina').update({
        name: 'Adrenalina 1mg Updated'
      })
    );
  });

  test('sanitary NO puede actualizar catalogItems', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('catalogItems').doc('cat_adrenalina').update({
        critical: false
      })
    );
  });

  // DELETE - Solo programmer
  test('programmer PUEDE eliminar catalogItems', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(
      db.collection('catalogItems').doc('cat_adrenalina').delete()
    );
  });

  test('logistics NO puede eliminar catalogItems', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertFails(
      db.collection('catalogItems').doc('cat_adrenalina').delete()
    );
  });
});

// ============================================================================
// TESTS: AUDIT LOGS COLLECTION (Read-Only)
// ============================================================================

describe('AuditLogs Collection Security', () => {
  beforeEach(async () => {
    await setupTestData();
    await createWithAdmin('auditLogs', 'log_001', {
      action: 'create',
      entity: 'kit',
      entityId: 'kit_trauma',
      userId: 'programmer_uid',
      timestamp: new Date()
    });
  });

  // READ
  test('todos los autenticados pueden leer auditLogs', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertSucceeds(db.collection('auditLogs').get());
  });

  test('programmer puede leer auditLogs', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertSucceeds(db.collection('auditLogs').doc('log_001').get());
  });

  // CREATE - Nadie puede desde cliente
  test('NI programmer puede crear auditLogs', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertFails(
      db.collection('auditLogs').doc('log_new').set({
        action: 'delete',
        entity: 'user',
        entityId: 'user_xxx',
        userId: 'programmer_uid',
        timestamp: new Date()
      })
    );
  });

  test('logistics NO puede crear auditLogs', async () => {
    const db = getAuthContext('logistics_uid').firestore();
    await assertFails(
      db.collection('auditLogs').doc('log_hack').set({
        action: 'create',
        entity: 'base',
        entityId: 'base_xxx',
        userId: 'logistics_uid',
        timestamp: new Date()
      })
    );
  });

  // UPDATE - Nadie puede
  test('NI programmer puede actualizar auditLogs', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertFails(
      db.collection('auditLogs').doc('log_001').update({
        action: 'read'
      })
    );
  });

  // DELETE - Nadie puede
  test('NI programmer puede eliminar auditLogs', async () => {
    const db = getAuthContext('programmer_uid').firestore();
    await assertFails(
      db.collection('auditLogs').doc('log_001').delete()
    );
  });

  test('sanitary NO puede eliminar auditLogs', async () => {
    const db = getAuthContext('sanitary_uid').firestore();
    await assertFails(
      db.collection('auditLogs').doc('log_001').delete()
    );
  });
});

// ============================================================================
// TESTS: EDGE CASES Y SEGURIDAD
// ============================================================================

describe('Security Edge Cases', () => {
  beforeEach(async () => {
    await setupTestData();
  });

  test('usuario con roleId inválido NO puede hacer nada', async () => {
    // Crear usuario con rol inexistente
    await createWithAdmin('users', 'invalid_user', {
      uid: 'invalid_user',
      username: 'hacker',
      email: 'hacker@evil.com',
      roleId: 'role_nonexistent',
      active: true
    });

    const db = getAuthContext('invalid_user').firestore();
    
    // Debería fallar porque el rol no existe
    await assertFails(
      db.collection('bases').doc('hack_base').set({
        code: 'HACK',
        name: 'Hacked Base',
        vehicleIds: []
      })
    );
  });

  test('usuario desactivado todavía puede leer (reglas no verifican active)', async () => {
    // Nota: Las reglas actuales no verifican el campo 'active'
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('sanitary_uid').update({
        active: false
      });
    });

    const db = getAuthContext('sanitary_uid').firestore();
    // Todavía puede leer porque las reglas solo verifican autenticación y rol
    await assertSucceeds(db.collection('bases').get());
  });
});