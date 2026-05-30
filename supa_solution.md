```rust
use std::time::{Instant, Duration};

pub fn benchmark() {
    let start = Instant::now();
    let mut count = 0;
    let mut register = 0;
    let mut lock = std::sync::Mutex::new(0);
    let mut time = 0;

    while count < 10000 {
        let mut value = register.lock().unwrap();
        if value > 1000 {
            time += 1;
        }
        register.lock().unwrap() += 1;
        count += 1;
    }

    println!("Time taken: {:?}", start.elapsed());
}
```