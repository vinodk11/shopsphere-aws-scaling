-- ==============================================================================
-- ShopSphere Database Schema & Seed Data (Stage 3 - Amazon RDS PostgreSQL)
-- Safe, idempotent execution for concurrent Auto Scaling Group bootstrapping
-- ==============================================================================

-- 1. Categories Table
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Products Table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL,
    stock_quantity INTEGER NOT NULL DEFAULT 50,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Orders Table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    customer_email VARCHAR(150) NOT NULL,
    shipping_address TEXT NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'COMPLETED',
    served_by_host VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Order Items Table
CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Ensure served_by_host column exists if upgraded from previous stages
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' AND column_name = 'served_by_host'
    ) THEN
        ALTER TABLE orders ADD COLUMN served_by_host VARCHAR(100);
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- Seed Initial Taxonomy Categories (Idempotent)
-- ------------------------------------------------------------------------------
INSERT INTO categories (id, name, description) VALUES
(1, 'Audio & Electronics', 'High fidelity audio equipment, noise-canceling gear, and accessories'),
(2, 'Wearables', 'Next-gen smart wearables, fitness trackers, and connected devices'),
(3, 'Smart Home', 'Connected smart lamps, voice hubs, and home automation systems'),
(4, 'Computer Peripherals', 'Productivity gear, mechanical keyboards, and precision peripherals')
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------------------------
-- Seed Initial Product Catalog (Idempotent)
-- ------------------------------------------------------------------------------
INSERT INTO products (id, category_id, name, description, price, stock_quantity, image_url) VALUES
(1, 1, 'CloudBeats ANC Wireless Headphones', 'Active noise cancelling wireless headphones with 40-hour battery life and spatial audio.', 199.99, 45, 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500&auto=format&fit=crop&q=60'),
(2, 2, 'ShopSphere Apex Smart Watch', 'AMOLED display, continuous ECG & SpO2 tracking, 7-day battery, and 5ATM water resistance.', 249.99, 30, 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500&auto=format&fit=crop&q=60'),
(3, 1, 'UltraHD 4K Action Camera', 'Compact waterproof 4K/60fps camera with 6-axis gyro stabilization and dual screens.', 129.99, 25, 'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=500&auto=format&fit=crop&q=60'),
(4, 3, 'Aurora Smart RGB Desk Lamp', 'Voice-controlled ambient lighting with custom gradients, timer routines, and adaptive brightness.', 49.99, 60, 'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?w=500&auto=format&fit=crop&q=60'),
(5, 4, 'CyberDeck RGB Mechanical Keyboard', 'Hot-swappable tactile mechanical switches, PBT keycaps, and aircraft-grade aluminum chassis.', 89.99, 40, 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=500&auto=format&fit=crop&q=60'),
(6, 1, 'HyperCharge 20000mAh Power Bank', '65W USB-C Power Delivery fast-charging power bank for laptops, tablets, and smartphones.', 39.99, 75, 'https://images.unsplash.com/photo-1609592426507-da665123d537?w=500&auto=format&fit=crop&q=60')
ON CONFLICT (id) DO NOTHING;

-- Synchronize sequence counters
SELECT setval('categories_id_seq', COALESCE((SELECT MAX(id) FROM categories), 1));
SELECT setval('products_id_seq', COALESCE((SELECT MAX(id) FROM products), 1));
