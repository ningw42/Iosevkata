// This is a Rust code snippet to demonstrate a monospaced font.
fn main() {
    // Variables and types
    let greeting: &str = "Hello, world!";
    let number: i32 = 42;

    // A simple function
    fn add(a: i32, b: i32) -> i32 {
        a + b
    }

    // Using the function
    let result = add(number, 58);
    println!("{} The answer is: {}", greeting, result);

    // A struct and its implementation
    struct Point {
        x: f64,
        y: f64,
    }

    impl Point {
        fn new(x: f64, y: f64) -> Self {
            Point { x, y }
        }

        fn distance(&self, other: &Point) -> f64 {
            ((self.x - other.x).powi(2) + (self.y - other.y).powi(2)).sqrt()
        }
    }

    // Using the struct
    let p1 = Point::new(0.0, 0.0);
    let p2 = Point::new(3.0, 4.0);
    println!("Distance between p1 and p2: {}", p1.distance(&p2));
}
