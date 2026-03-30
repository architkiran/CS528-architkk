import re

with open("train_models.py", "r") as f:
    content = f.read()

old_query = '''    query = """
        SELECT
            r.client_ip,
            ic.country,
            r.gender,
            r.age,
            r.income,
            r.is_banned,
            r.time_of_day,
            r.requested_file
        FROM requests r
        JOIN ip_country ic ON r.client_ip = ic.client_ip
        WHERE r.gender  != \'\'
          AND r.income  != \'\'
          AND ic.country != \'\'
    """'''

new_query = '''    query = """
        SELECT
            client_ip,
            country,
            gender,
            age,
            income,
            is_banned,
            time_of_day,
            requested_file
        FROM requests
        WHERE gender  != \'\'
          AND income  != \'\'
          AND country != \'\'
    """'''

content = content.replace(old_query, new_query)

with open("train_models.py", "w") as f:
    f.write(content)

print("Done!")
