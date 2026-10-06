-- Création des tables 
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    category VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID', 'SHIPPED', 'CANCELLED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0)
);

-- Trigger pour mettre à jour le total de la commande

CREATE OR REPLACE FUNCTION update_order_total()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE orders
    SET total_amount = (
        SELECT COALESCE(SUM(quantity * unit_price), 0)
        FROM order_items
        WHERE order_id = COALESCE(NEW.order_id, OLD.order_id)
    )
    WHERE id = COALESCE(NEW.order_id, OLD.order_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_after_order_item_change
AFTER INSERT OR UPDATE OR DELETE ON order_items
FOR EACH ROW
EXECUTE FUNCTION update_order_total();

-- Résumé des ventes par produit

CREATE OR REPLACE VIEW v_product_sales_summary AS
SELECT 
    p.id AS product_id,
    p.name AS product_name,
    p.category,
    COALESCE(SUM(oi.quantity), 0) AS total_sold,
    COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS total_revenue
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
GROUP BY p.id, p.name, p.category;

-- Insertion de données

-- 500 utilisateurs
INSERT INTO users (email, first_name, last_name)
SELECT 
    'user_' || seq || '@example.com',
    'Prenom' || seq,
    'Nom' || seq
FROM generate_series(1, 500) AS seq;

-- 1000 produits
INSERT INTO products (name, description, price, stock, category)
SELECT 
    'Produit ' || seq,
    'Description détaillée pour le produit référence ' || seq,
    ROUND((random() * 200 + 5)::numeric, 2),
    (random() * 100)::int,
    (ARRAY['Electronique', 'Maison', 'Sport', 'Livres', 'Mode'])[(seq % 5) + 1]
FROM generate_series(1, 1000) AS seq;

-- 1500 commandes
INSERT INTO orders (user_id, status, created_at)
SELECT 
    (random() * 499 + 1)::int,
    (ARRAY['PENDING', 'PAID', 'SHIPPED', 'CANCELLED'])[(seq % 4) + 1],
    NOW() - (random() * interval '60 days')
FROM generate_series(1, 1500) AS seq;

-- 3000 lignes de commande
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT 
    (random() * 1499 + 1)::int,
    (random() * 999 + 1)::int,
    (random() * 3 + 1)::int,
    ROUND((random() * 100 + 10)::numeric, 2)
FROM generate_series(1, 3000) AS seq;

-- 5. Gestion des droits
CREATE USER app_user WITH PASSWORD 'app_secure_password';
GRANT CONNECT ON DATABASE ecommerce TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;