
import sys
from faker import Faker
import polars as pl

csv_path = sys.argv[1]

fake = Faker()

df = pl.read_csv(csv_path)

names = []
for _ in range(len(df)):
  names.append(fake.user_name())

df = df.with_columns(pl.Series(name="username", values=names))

df = df.rename({"E-Mail Teilnehmer*in":"email"})[["username","email"]]

print(df.head())

print(len(df))

df.write_csv(csv_path)