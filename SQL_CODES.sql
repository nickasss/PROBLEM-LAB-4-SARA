-- Part 2: Logical Design - SQL Table Definitions

CREATE TABLE Books (
    ISBN VARCHAR(13) PRIMARY KEY,
    Title VARCHAR(255) NOT NULL,
    Author VARCHAR(255) NOT NULL,
    Genre VARCHAR(50),
    PublishedYear INT,
    QuantityAvailable INT NOT NULL CHECK (QuantityAvailable >= 0)
);

CREATE TABLE Users (
    UserID SERIAL PRIMARY KEY,
    FullName VARCHAR(255) NOT NULL,
    EmailAddress VARCHAR(255) UNIQUE NOT NULL,
    MembershipDate DATE NOT NULL
);

CREATE TABLE BookLoans (
    LoanID SERIAL PRIMARY KEY,
    UserID INT NOT NULL,
    ISBN VARCHAR(13) NOT NULL,
    LoanDate DATE NOT NULL,
    ReturnDate DATE,
    Status VARCHAR(50) NOT NULL,
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    FOREIGN KEY (ISBN) REFERENCES Books(ISBN)
);

-- Part 3: SQL Queries

INSERT INTO Books (ISBN, Title, Author, Genre, PublishedYear, QuantityAvailable)
VALUES ('9780131103627', 'The Pragmatic Programmer', 'Andrew Hunt', 'Technology', 1999, 5);

INSERT INTO Users (FullName, EmailAddress, MembershipDate)
VALUES ('Paul Ardiente', 'paulandrei@gmail.com', '2024-12-01');

INSERT INTO BookLoans (UserID, ISBN, LoanDate, Status)
VALUES (1, '9780131103627', '2024-12-10', 'borrowed');

SELECT B.Title, B.Author, BL.LoanDate, BL.ReturnDate, BL.Status
FROM BookLoans BL
JOIN Books B ON BL.ISBN = B.ISBN
WHERE BL.UserID = 1;

SELECT B.Title, U.FullName, BL.LoanDate, BL.ReturnDate, BL.Status
FROM BookLoans BL
JOIN Books B ON BL.ISBN = B.ISBN
JOIN Users U ON BL.UserID = U.UserID
WHERE BL.Status = 'borrowed' AND BL.ReturnDate < CURRENT_DATE;

-- Part 4: Data Integrity and Optimization

-- to prevent users from borrowing books when no copies are available, we can implement a trigger.
-- The trigger checks if the Quantityy of the book in the library is greater than zero before allowing the loan.
-- If the quantity is greater than zero, the book loan is allowed, and the available quantity is decremented by 1.
-- If the quantity is zero or less, an exception is Raised, preventing the book from being borrowed.
-- This ensures that no book loan is recorded if the book is out of stock, thus maintaining accurate inventory.


CREATE OR REPLACE FUNCTION check_book_availability() 
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT QuantityAvailable FROM Books WHERE ISBN = NEW.ISBN) <= 0 THEN
        RAISE EXCEPTION 'No available copies of the book';
    END IF;
    UPDATE Books SET QuantityAvailable = QuantityAvailable - 1 WHERE ISBN = NEW.ISBN;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_borrow_when_no_copies
BEFORE INSERT ON BookLoans
FOR EACH ROW EXECUTE FUNCTION check_book_availability();

-- 2. \fast Retrieval of Overdue Loans
-- to speed up the retrieval of overdue loans, we create an index on the ReturnDate column of the BookLoans table.
-- This index helps the database quickly locate records with a return date earlier than the current date, which indicates the loan is overdue.
-- The query below retrieves all overdue loans by joining the Books and Users tables and checking for loans where the ReturnDate is before the current date.
CREATE INDEX idx_return_date ON BookLoans (ReturnDate);

SELECT B.Title, U.FullName, BL.LoanDate, BL.ReturnDate, BL.Status
FROM BookLoans BL
JOIN Books B ON BL.ISBN = B.ISBN
JOIN Users U ON BL.UserID = U.UserID
WHERE BL.Status = 'borrowed' AND BL.ReturnDate < CURRENT_DATE;


-- part 5: reflection

-- 1. challenges when scaling the database to handle millions of users and books:
-- a. performance issues: as the number of users and books grows, queries may become slower due to the larger amount of data. 
--    one solution is to use indexing on frequently queried fields (like isbn, user id, and return date???) to speed up retrieval.
--    partitioning tables based on certain criteria (e.g., user id ranges or book genres) can also help manage large datasets efficiently.
-- b. database locking: when multiple users try to borrow or return books at the same time, database locks can occur, slowing down transactions.
--    to solve this, consider implementing row-level locking and optimizing transactions to minimize lock contention.
-- c. maintaining data consistency: with millions of users and books, ensuring data consistency across all transactions is critical.
--    one solution is to implement strict referential integrity with foreign key constraints, as well as using transactional consistency mechanisms like two-phase commit.

-- 2. possible solutions:
-- a. indexing on frequently queried columns, such as isbn, user id, and return date, will help speed up searches and improve query performance.
-- b. partitioning large tables to break them into smaller, more manageable pieces can reduce the load on the database and improve response times.
-- c. implementing row-level locking and optimizing database transactions can help reduce conflicts and ensure smooth concurrent operations.
-- d. maintaining referential integrity with foreign key constraints, along with using transactional consistency mechanisms, will ensure that the data stays consistent across all operations, even at scale.


-- ASSUMPTIONS

-- the library system allows physical and digital copies of books. quantityavailable represents physical copies.
-- each user must have a unique membership and only one active membership at a time.

-- the loan period is 14 days, after which books are overdue. loans cannot be made if no copies are available.
-- each book is uniquely identified by its isbn, and quantity is updated once returned.

-- users can borrow a maximum of 5 books at a time. late fee system will be added later, and loan status tracks borrowing, return, or overdue.


