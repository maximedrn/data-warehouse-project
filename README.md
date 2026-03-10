# Data warehouse project

## Project description

This project implements a decision support system for the company MoreMovies.
The company acquired three stores:

- MovieMegaMart
- BuckBoaster
- MetroStarlet

Each store has its own information system. The objective is to integrate these systems into a single data warehouse in order to analyze sales and rentals of movies and related products.

Two architectures must be implemented:

- Architecture 1: reporting tool connected directly to the MySQL data warehouse
- Architecture 2: reporting tool connected to the warehouse through a Mondrian ROLAP server

## System architecture

```mermaid
flowchart TD

A[Source Databases - Access]
B[ETL - Pentaho Data Integration]
C[Integrated Database - MySQL]
D[Data Warehouse - Star Schema]
E[Mondrian ROLAP Server]
F[Reporting Client]

A --> B
B --> C
C --> D
D --> E
E --> F
```

## Prerequisites

- Docker
- Docker Compose
- Visual Paradigm

## Start the infrastructure

```bash
docker compose up -d
```
