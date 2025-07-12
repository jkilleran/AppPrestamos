-- Agregar columna categoria_minima a loan_options si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='loan_options' AND column_name='categoria_minima'
    ) THEN
        ALTER TABLE loan_options ADD COLUMN categoria_minima VARCHAR(20) DEFAULT 'Hierro';
    END IF;
END$$;

-- Opcional: establecer categoria_minima en las opciones existentes (ejemplo: todas a Hierro)
UPDATE loan_options SET categoria_minima = 'Hierro' WHERE categoria_minima IS NULL;

-- Asegurar que la columna no acepte NULL
ALTER TABLE loan_options ALTER COLUMN categoria_minima SET NOT NULL;
