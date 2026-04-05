\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{project_report}[Project report]

\LoadClass[a4paper,11pt]{article}

\RequirePackage{xcolor}
\definecolor{accent}{HTML}{2563EB}
\definecolor{linkcolor}{HTML}{1D4ED8}
\definecolor{codebg}{HTML}{F1F5F9}
\definecolor{codeframe}{HTML}{94A3B8}
\definecolor{sqlkw}{HTML}{0000CC}
\definecolor{sqlkw2}{HTML}{8B008B}
\definecolor{sqlstr}{HTML}{008000}
\definecolor{sqlcmt}{HTML}{808080}
\definecolor{sqlnum}{HTML}{B05A00}
\definecolor{tableline}{HTML}{94A3B8}

\RequirePackage[utf8]{inputenc}
\RequirePackage[T1]{fontenc}
\RequirePackage{lmodern}
\RequirePackage{geometry}
\RequirePackage{setspace}
\RequirePackage{titlesec}
\RequirePackage{enumitem}
\RequirePackage{graphicx}
\RequirePackage{fancyhdr}

\providecommand{\passthrough}[1]{#1}
\RequirePackage{listings}

\lstdefinelanguage{SQL}{
  morekeywords={[1]SELECT,FROM,WHERE,INSERT,UPDATE,DELETE,CREATE,DROP,
    ALTER,TABLE,INDEX,VIEW,DATABASE,SCHEMA,GRANT,REVOKE,COMMIT,ROLLBACK,
    BEGIN,END,DECLARE,SET,INTO,VALUES,AS,ON,JOIN,LEFT,RIGHT,INNER,
    OUTER,FULL,CROSS,UNION,ALL,DISTINCT,ORDER,BY,GROUP,HAVING,
    LIMIT,OFFSET,IN,NOT,AND,OR,IS,NULL,TRUE,FALSE,
    PRIMARY,FOREIGN,KEY,REFERENCES,UNIQUE,CHECK,DEFAULT,CONSTRAINT,
    AUTO_INCREMENT,SERIAL,IF,EXISTS,CASE,WHEN,THEN,ELSE,LIKE,
    BETWEEN,CAST,COALESCE,WITH,RECURSIVE,RETURNING},
  morekeywords={[2]INT,INTEGER,BIGINT,SMALLINT,TINYINT,DECIMAL,NUMERIC,
    FLOAT,REAL,DOUBLE,BOOLEAN,CHAR,VARCHAR,TEXT,BLOB,DATE,TIME,
    DATETIME,TIMESTAMP,YEAR,ENUM,SET,JSON,UUID,BINARY,BIT,
    MEDIUMINT,LONGTEXT,MEDIUMTEXT,TINYTEXT},
  sensitive=false,
  morestring=[b]',
  morestring=[b]",
  morecomment=[l]{--},
  morecomment=[s]{/*}{*/},
}

\lstset{
  basicstyle=\ttfamily\scriptsize,
  breaklines=true,
  breakatwhitespace=false,
  frame=single,
  backgroundcolor=\color{codebg},
  rulecolor=\color{codeframe},
  xleftmargin=3pt,
  xrightmargin=3pt,
  aboveskip=6pt,
  belowskip=6pt,
  showstringspaces=false,
  keywordstyle=[1]\color{sqlkw}\bfseries,
  keywordstyle=[2]\color{sqlkw2},
  stringstyle=\color{sqlstr},
  commentstyle=\color{sqlcmt}\itshape,
  numberstyle=\tiny\color{sqlnum},
}

\RequirePackage{tabularx}
\RequirePackage{colortbl}
\RequirePackage{booktabs}
\RequirePackage{longtable}
\RequirePackage{array}
\RequirePackage{calc}
\arrayrulecolor{tableline}
\renewcommand{\arraystretch}{1.2}
\setlength{\tabcolsep}{4pt}
\setlength{\LTleft}{0pt}
\setlength{\LTright}{0pt}

\setcounter{tocdepth}{2}
\renewcommand{\contentsname}{\LARGE\bfseries Table des matieres}
\makeatletter
\renewcommand{\@dotsep}{4.5}
\makeatother

\RequirePackage[
  colorlinks=true,
  linkcolor=black,
  urlcolor=linkcolor,
]{hyperref}

\geometry{
  top=1.8cm,
  bottom=1.8cm,
  left=1.5cm,
  right=1.5cm,
  heightrounded
}

\setstretch{1.15}
\setlength{\parindent}{0pt}
\setlength{\parskip}{6pt}

\pagestyle{fancy}
\fancyhf{}
\renewcommand{\headrulewidth}{0pt}
\renewcommand{\footrulewidth}{0pt}
\fancyfoot{}

\titleformat{\section}
  {\LARGE\bfseries\centering}
  {}
  {0pt}
  {}
\titlespacing*{\section}{0pt}{14pt}{6pt}

\titleformat{\subsection}
  {\normalsize\bfseries\raggedright}
  {}
  {0pt}
  {}
\titlespacing*{\subsection}{0pt}{10pt}{4pt}

\setlist[itemize]{
    label=\textbullet,
    leftmargin=1.1cm,
    itemsep=-2pt,
    topsep=3pt
}


\newcommand{\SessionTitle}[1]{%
  \clearpage
  \vspace*{\fill}
  {\centering\LARGE\bfseries #1\par}%
  \vspace*{\fill}
  \addcontentsline{toc}{section}{#1}%
}

\newcommand{\Section}[1]{%
  \addcontentsline{toc}{section}{#1}%
  \vspace{16pt}%
  {\Large\bfseries #1}\par\vspace{4pt}%
}

\newcommand{\SubSection}[1]{%
  \addcontentsline{toc}{subsection}{#1}%
  \vspace{12pt}%
  {\bfseries #1}\par\vspace{4pt}%
}

\endinput
