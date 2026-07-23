export const metadata = {
  title: 'KEPR Inventory',
  description: 'Warehouse and apartment inventory management',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body style={{ margin: 0 }}>{children}</body>
    </html>
  );
}
