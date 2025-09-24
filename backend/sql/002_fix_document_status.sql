-- =============================================================
-- Script: 002_fix_document_status.sql
-- Objetivo:
--   * Asegurar columnas para manejo de estado de documentos
--   * Normalizar cédulas (remover caracteres no numéricos)
--   * Detectar duplicados de cédula y mostrar en logs
--   * Crear índices (único para cédula si no hay duplicados, GIN para notas)
--   * Agregar constraint de rango para bitmask (0..255)
--   * Idempotente: se puede ejecutar varias veces sin romper nada
-- =============================================================
-- Uso recomendado:
--   psql (u otra herramienta) -> ejecutar este archivo completo.
--   Revise los NOTICE para ver si hay duplicados pendientes.
--   Si hay duplicados, corríjalos manualmente (UPDATE ...) y vuelva a ejecutar.
-- =============================================================

BEGIN;

-- Opcional: Limitar tiempos para evitar bloqueos largos en producción
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';

-- 1. Asegurar columnas requeridas
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS document_status_code INTEGER DEFAULT 0;
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS document_status_notes JSONB DEFAULT '{}'::jsonb;

-- 2. Normalizar cédulas (eliminar cualquier carácter no numérico)
UPDATE users
SET cedula = regexp_replace(cedula, '[^0-9]', '', 'g')
WHERE cedula IS NOT NULL
  AND cedula ~ '[^0-9]';

-- 3. Reportar duplicados de cédula (NO se modifican datos aquí)
DO $$
DECLARE r RECORD; dup_count INT;
BEGIN
  FOR r IN (
    SELECT cedula, array_agg(id ORDER BY id) AS ids, COUNT(*) AS c
    FROM users
    WHERE cedula IS NOT NULL AND cedula <> ''
    GROUP BY cedula
    HAVING COUNT(*) > 1
  ) LOOP
    RAISE NOTICE 'DUPLICADO cedula=% ids=% (total=%)', r.cedula, r.ids, r.c;
  END LOOP;

  SELECT COUNT(*) INTO dup_count FROM (
    SELECT 1
    FROM users
    WHERE cedula IS NOT NULL AND cedula <> ''
    GROUP BY cedula
    HAVING COUNT(*) > 1
  ) z;

  IF dup_count > 0 THEN
    RAISE NOTICE 'Hay % cédulas duplicadas. Corregir manualmente y re-ejecutar para crear índice único.', dup_count;
  ELSE
    RAISE NOTICE 'No hay duplicados de cédula. Se intentará crear el índice único.';
  END IF;
END $$;

-- 4. Crear índice único sólo si no existen duplicados
DO $$
DECLARE dup_count INT;
BEGIN
  SELECT COUNT(*) INTO dup_count FROM (
    SELECT 1
    FROM users
    WHERE cedula IS NOT NULL AND cedula <> ''
    GROUP BY cedula
    HAVING COUNT(*) > 1
  ) z;
  IF dup_count = 0 THEN
    BEGIN
      CREATE UNIQUE INDEX IF NOT EXISTS users_cedula_uidx ON users(cedula);
      RAISE NOTICE 'Índice único users_cedula_uidx verificado / creado.';
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'No se pudo crear índice único users_cedula_uidx: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE 'Se omite creación de índice único: todavía hay duplicados (%).', dup_count;
  END IF;
END $$;

-- 5. Índice GIN sobre JSONB de notas
DO $$
BEGIN
  BEGIN
    CREATE INDEX IF NOT EXISTS users_document_status_notes_gin ON users USING GIN (document_status_notes);
    RAISE NOTICE 'Índice GIN users_document_status_notes_gin verificado / creado.';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'No se pudo crear índice GIN: %', SQLERRM;
  END;
END $$;

-- 6. Constraint de rango para bitmask (0..255)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_document_status_code_range'
  ) THEN
    BEGIN
      ALTER TABLE users ADD CONSTRAINT users_document_status_code_range CHECK (document_status_code BETWEEN 0 AND 255);
      RAISE NOTICE 'Constraint users_document_status_code_range creada.';
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'No se pudo crear constraint de rango: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE 'Constraint users_document_status_code_range ya existe.';
  END IF;
END $$;

-- 7. Resumen rápido
DO $$
DECLARE total_users INT; con_notas INT; con_codigo INT; duplicados INT;
BEGIN
  SELECT COUNT(*) INTO total_users FROM users;
  SELECT COUNT(*) INTO con_notas FROM users WHERE document_status_notes IS NOT NULL;
  SELECT COUNT(*) INTO con_codigo FROM users WHERE document_status_code IS NOT NULL;
  SELECT COUNT(*) INTO duplicados FROM (
    SELECT 1 FROM users WHERE cedula IS NOT NULL AND cedula <> '' GROUP BY cedula HAVING COUNT(*)>1
  ) q;
  RAISE NOTICE 'Resumen -> usuarios=% con_codigo=% con_notas=% duplicados_cedula=%', total_users, con_codigo, con_notas, duplicados;
END $$;

COMMIT;

-- =============================================================
-- PASOS PARA CORREGIR DUPLICADOS (ejemplos):
-- 1) Identificar duplicados (saldrán como NOTICE al correr script) o manualmente:
--    SELECT cedula, array_agg(id ORDER BY id) ids, COUNT(*) FROM users
--    WHERE cedula IS NOT NULL AND cedula <> '' GROUP BY cedula HAVING COUNT(*)>1;
-- 2) Elegir un id "principal" que conserve la cédula correcta.
-- 3) Actualizar los otros registros con la cédula verdadera que les corresponda.
--    UPDATE users SET cedula = '11223344556' WHERE id = 42;  -- Debe ser un número de 11 dígitos.
-- 4) Re-ejecutar este script para que (al ya no haber duplicados) se cree el índice único.
-- =============================================================
-- NOTA: Si la columna cedula es NOT NULL y temporalmente quisiera limpiar duplicados
--       (NO recomendado salvo que sepa lo que hace), tendría que:
--       ALTER TABLE users ALTER COLUMN cedula DROP NOT NULL;
--       UPDATE users SET cedula = NULL WHERE id IN (... ids secundarios ...);
--       (luego corregir manual y volver a poner NOT NULL si desea)
--       ALTER TABLE users ALTER COLUMN cedula SET NOT NULL;
--       Esto NO se automatiza para evitar pérdida silenciosa de datos.
-- =============================================================
