FROM mysql:5.7.20

COPY ./custom.cnf /etc/mysql/conf.d/
RUN chmod 644 /etc/mysql/conf.d/custom.cnf

CMD ["mysqld"]
